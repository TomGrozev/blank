import Config

config :blank,
  force_ecto_schema: true,
  endpoint: TestAppWeb.Endpoint,
  repo: TestApp.Repo,
  user_module: TestApp.Accounts.User,
  user_table: :test_app_users,
  user_table_pk: :id,
  user_assigns: :current_user,
  use_local_timezone: false,
  additional_exporters: []

# Configure the test endpoint
config :test_app, TestAppWeb.Endpoint,
  url: [host: "localhost", port: 4000, scheme: "http"],
  secret_key_base: "test_secret_key_base_for_blank_testing_only_at_least_64_bytes_long!",
  render_errors: [
    formats: [html: TestAppWeb.ErrorHTML, json: TestAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Blank.PubSub,
  live_view: [signing_salt: "GL2ATuCmtzWZjQBB"]

# Configure Ecto
config :test_app, ecto_repos: [TestApp.Repo]
