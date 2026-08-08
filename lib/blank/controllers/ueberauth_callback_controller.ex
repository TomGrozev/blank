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

  defp handle_success(conn, auth) do
    provider = auth.provider
    uid = auth.uid
    email = auth.info.email
    name = auth.info.name

    with nil <- Accounts.get_user_by_provider_and_uid(provider, uid),
         {:ok, user} <-
           Accounts.create_ueberauth_user(%{
             email: email,
             name: name,
             provider: to_string(provider),
             external_uid: uid,
             roles: ["member"]
           }) do
      audit_context = conn.assigns[:audit_context] || AuditLog.system()

      Blank.Audit.log!(audit_context, "accounts.user_created", %{
        email: email,
        roles: user.roles
      })

      conn
      |> put_flash(:info, "Welcome!")
      |> Auth.log_in(user)
    else
      %Accounts.User{} = existing_user ->
        # User exists, refresh their info
        case Accounts.refresh_ueberauth_user(existing_user, %{email: email, name: name}) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Welcome back!")
            |> Auth.log_in(user)

          {:error, _changeset} ->
            redirect_with_error(
              conn,
              "Could not update your account. Please try again or contact support."
            )
        end

      {:error, _changeset} ->
        redirect_with_error(
          conn,
          "Could not create your account. Please try again or contact support."
        )

      _ ->
        redirect_with_error(conn, "Authentication failed. Please try again.")
    end
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
