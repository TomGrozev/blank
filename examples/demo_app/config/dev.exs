import Config

config :demo_app, DemoApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :demo_app, DemoAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev-only-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-to-accept-it",
  watchers: []

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
