defmodule Blank.Application do
  @moduledoc false

  use Application

  @doc """
  Starts the blank application
  """
  @spec start(Application.start_type(), term()) ::
          {:ok, pid()} | {:error, {:already_started, pid()} | {:shutdown, term()} | term()}
  def start(_, _) do
    validate_ueberauth_config!()
    validate_authorization_config!()

    children = [
      # {DynamicSupervisor, name: Blank.DynamicSupervisor, strategy: :one_for_one},
      {Phoenix.PubSub, name: Blank.PubSub},
      Blank.DownloadAgent,
      Blank.Presence
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp validate_authorization_config! do
    config = Application.get_env(:blank, :authorization, [])
    roles = Keyword.get(config, :roles, [])

    unless is_list(roles) and Enum.all?(roles, &is_atom/1) do
      raise """
      Blank authorization config is invalid.

      The :roles key must be a list of atoms:

          config :blank, :authorization, roles: [:payment_manager, :content_editor]

      Got: #{inspect(roles)}
      """
    end

    # Compute and cache the allowed-set at boot
    Blank.Config.compute_and_cache_allowed_roles()
    :ok
  end

  defp validate_ueberauth_config! do
    # Only validate ueberauth config if local auth is disabled
    # (i.e., ueberauth is the only auth method)
    local_auth_enabled? = Blank.Plugs.Auth.local_login_enabled?()

    if not local_auth_enabled? and Code.ensure_loaded?(Ueberauth) do
      config = Application.get_env(:ueberauth, Ueberauth, [])
      providers = Keyword.get(config, :providers, [])

      if providers == [] do
        raise """
        Blank requires at least one Ueberauth provider to be configured when local auth is disabled.
        Please add providers to your Ueberauth config:

            config :ueberauth, Ueberauth,
              providers: [google: {Ueberauth.Strategy.Google, []}]

        Or enable local auth:

            config :blank, :auth, local_login: :enabled
        """
      end
    end
  end
end
