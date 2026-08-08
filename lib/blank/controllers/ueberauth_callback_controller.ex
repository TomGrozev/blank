defmodule Blank.Controllers.UeberauthCallbackController do
  @moduledoc """
  Handles ueberauth callbacks for all configured providers.
  """
  use Blank.Web, :controller

  alias Blank.Accounts
  alias Blank.Audit.AuditLog
  alias Blank.Plugs.Auth

  @doc """
  Called by ueberauth after authentication attempt.
  Reads `:ueberauth_auth` or `:ueberauth_failure` from conn assigns.
  """
  def callback(conn, _params) do
    # Manually invoke Ueberauth to populate assigns
    # This defers provider resolution from compile-time to runtime
    conn = maybe_run_ueberauth(conn)

    case conn.assigns do
      %{ueberauth_auth: %Ueberauth.Auth{} = auth} ->
        handle_success(conn, auth)

      %{ueberauth_failure: %Ueberauth.Failure{} = failure} ->
        handle_failure(conn, failure)

      _ ->
        handle_unknown(conn)
    end
  end

  defp maybe_run_ueberauth(conn) do
    # If ueberauth assigns are already set (e.g., by the router pipeline), skip re-running
    if Map.has_key?(conn.assigns, :ueberauth_auth) or
         Map.has_key?(conn.assigns, :ueberauth_failure) do
      conn
    else
      providers = Application.get_env(:ueberauth, Ueberauth, [])[:providers] || []

      if providers == [] do
        conn
      else
        Ueberauth.call(conn, Ueberauth.init([]))
      end
    end
  rescue
    # If Ueberauth.init fails for any reason, return conn unchanged
    _ -> conn
  end

  defp handle_success(conn, %Ueberauth.Auth{} = auth) do
    audit_context = conn.assigns[:audit_context] || AuditLog.system()

    case resolve_roles(auth) do
      {:ok, mapper_roles} ->
        do_handle_success(conn, auth, mapper_roles, audit_context)

      {:error, reason} ->
        fail_login(conn, auth, reason, audit_context)
    end
  end

  # Resolves roles from the configured role mapper.
  #
  # Returns:
  #   {:ok, nil} — no mapper configured
  #   {:ok, [atom()]} — mapper returned roles (floor applied, validated)
  #   {:error, reason} — mapper returned invalid roles
  defp resolve_roles(auth) do
    case Blank.Authorization.role_mapper_config() do
      nil ->
        {:ok, nil}

      {module, opts} ->
        raw_roles = module.map_claims(auth, opts)
        roles = if raw_roles == [], do: [:member], else: raw_roles

        case Blank.Authorization.validate_roles(roles) do
          :ok -> {:ok, roles}
          {:error, _invalid} -> {:error, "invalid_roles_from_mapper"}
        end
    end
  end

  defp do_handle_success(conn, auth, mapper_roles, audit_context) do
    provider = auth.provider
    uid = auth.uid
    email = auth.info.email
    name = auth.info.name

    case Accounts.get_user_by_provider_and_uid(provider, uid) do
      nil ->
        handle_new_user(conn, email, name, provider, uid, mapper_roles, audit_context)

      %Accounts.User{} = existing_user ->
        handle_existing_user(conn, existing_user, email, name, mapper_roles, audit_context)
    end
  end

  defp handle_new_user(conn, email, name, provider, uid, mapper_roles, audit_context) do
    initial_roles = mapper_roles || [:member]

    case Accounts.create_ueberauth_user(%{
           email: email,
           name: name,
           provider: to_string(provider),
           external_uid: uid,
           roles: initial_roles
         }) do
      {:ok, user} ->
        Blank.Audit.log!(audit_context, "accounts.user_created", %{
          email: email,
          roles: user.roles
        })

        conn
        |> put_flash(:info, "Welcome!")
        |> Auth.log_in(user)

      {:error, _changeset} ->
        redirect_with_error(
          conn,
          "Could not create your account. Please try again or contact support."
        )
    end
  end

  defp handle_existing_user(conn, existing_user, email, name, mapper_roles, audit_context) do
    case Accounts.refresh_ueberauth_user(existing_user, %{email: email, name: name}) do
      {:ok, user} ->
        handle_refreshed_user(conn, user, mapper_roles, audit_context)

      {:error, _changeset} ->
        redirect_with_error(
          conn,
          "Could not update your account. Please try again or contact support."
        )
    end
  end

  defp handle_refreshed_user(conn, user, mapper_roles, audit_context) do
    case mapper_roles do
      nil ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> Auth.log_in(user)

      roles ->
        handle_roles_update(conn, user, roles, audit_context)
    end
  end

  defp handle_roles_update(conn, user, roles, audit_context) do
    case Accounts.update_roles(user, roles,
           source: "idp_claim_mapper",
           audit_context: audit_context
         ) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> Auth.log_in(updated_user)

      {:error, _changeset} ->
        redirect_with_error(
          conn,
          "Could not update your account. Please try again or contact support."
        )
    end
  end

  defp fail_login(conn, %Ueberauth.Auth{} = auth, reason, audit_context) do
    Blank.Audit.log!(audit_context, "accounts.login_failed", %{
      email: auth.info.email || "unknown",
      reason: reason,
      provider: to_string(auth.provider)
    })

    conn
    |> put_flash(:error, "Authentication failed: invalid roles from identity provider")
    |> redirect_to_login()
  end

  defp handle_failure(conn, %Ueberauth.Failure{errors: errors}) do
    provider = conn.params["provider"] || "unknown"
    reason = Enum.map_join(errors, ", ", & &1.message)

    audit_context = conn.assigns[:audit_context] || AuditLog.system()

    Blank.Audit.log!(audit_context, "accounts.login_failed", %{
      email: "unknown",
      reason: reason,
      provider: provider
    })

    conn
    |> put_flash(:error, "Authentication failed: #{reason}")
    |> redirect_to_login()
  end

  defp handle_failure(conn, _failure) do
    handle_unknown(conn)
  end

  defp handle_unknown(conn) do
    provider = conn.params["provider"] || "unknown"

    audit_context = conn.assigns[:audit_context] || AuditLog.system()

    Blank.Audit.log!(audit_context, "accounts.login_failed", %{
      email: "unknown",
      reason: "unknown error",
      provider: provider
    })

    redirect_with_error(conn, "Authentication failed: unknown error")
  end

  defp redirect_with_error(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect_to_login()
  end

  defp redirect_to_login(conn) do
    prefix = conn.private[:phoenix_router].__blank_prefix__()
    redirect(conn, to: Path.join(prefix, "/log_in"))
  end
end
