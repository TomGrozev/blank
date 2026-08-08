import Config

config :blank,
  force_ecto_schema: true,
  endpoint: TestAppWeb.Endpoint,
  repo: TestApp.Repo,
  use_local_timezone: false,
  additional_exporters: [],
  authorization: [roles: [:content_editor]]

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

# Configure Ueberauth with a mock provider for testing
config :ueberauth, Ueberauth, providers: [google: {Blank.Test.UeberauthMockStrategy, []}]

# Configure Ecto
config :test_app, ecto_repos: [TestApp.Repo]
