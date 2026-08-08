import Config

config :blank,
  endpoint: DemoAppWeb.Endpoint,
  repo: DemoApp.Repo,
  use_local_timezone: true

config :blank, :auth,
  local_login: :dev_only,
  providers: %{github: %{name: "GitHub"}}

config :blank, :authorization,
  roles: [:payment_manager, :content_editor],
  policy_module: DemoApp.Policy,
  role_mapper:
    {Blank.Authorization.RoleMappers.GitHub,
     [
       team_slug_to_role: %{
         "payments-team" => :payment_manager
       }
     ]}

config :ueberauth, Ueberauth,
  providers: [github: {Ueberauth.Strategy.Github, []}]

config :demo_app, DemoApp.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

import_config "#{config_env()}.exs"
