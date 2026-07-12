import Config

config :demo_app, DemoApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :demo_app, DemoAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-only-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-to-accept-it",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
