# Make sure the libs are loaded
Application.ensure_all_started(:ex_unit)

# Ensure :test_app priv dir exists and is on the code path so
# Phoenix.LiveViewTest.ClientProxy can call Application.app_dir(:test_app, "priv")
test_app_priv = Path.join([File.cwd!(), "_build", "test", "lib", "test_app", "priv"])
File.mkdir_p!(test_app_priv)

test_app_ebin = Path.join([File.cwd!(), "_build", "test", "lib", "test_app", "ebin"])
File.mkdir_p!(test_app_ebin)

case :code.add_path(~c"#{test_app_ebin}") do
  true -> :ok
  {:error, :bad_directory} -> :ok
end

# Register the :test_app application so Application.app_dir/2 works
:application.load(:test_app, [{:vsn, ~c"0.0.0"}])

# Configure app env that must be set at runtime (compile_env has already been resolved)
Application.put_env(:blank, :endpoint, TestAppWeb.Endpoint)
Application.put_env(:blank, :repo, TestApp.Repo)
Application.put_env(:blank, :use_local_timezone, false)
Application.put_env(:blank, :additional_exporters, [])

# Clean the test database before each test run
test_db = Path.join(System.tmp_dir!(), "blank_test.sqlite3")
File.rm(test_db)
File.rm(test_db <> "-wal")
File.rm(test_db <> "-shm")

# Configure test_app repo to use the temp file
Application.put_env(:test_app, TestApp.Repo, database: test_db, pool: Ecto.Adapters.SQL.Sandbox)

# Start required applications
{:ok, _} = Application.ensure_all_started(:blank)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:ecto_sqlite3)
{:ok, _} = Application.ensure_all_started(:geo)

# Start the Repo
{:ok, _} = TestApp.Repo.start_link()

# Run migrations BEFORE enabling sandbox mode so they are committed directly
migrations_dir = Path.expand("support/migrations", __DIR__)

result =
  Ecto.Migrator.run(TestApp.Repo, migrations_dir, :up, all: true, log_migrations_sql: false)

IO.puts("Migrations applied: #{inspect(result)}")

# Set sandbox to manual mode (we control checkouts in DataCase)
Ecto.Adapters.SQL.Sandbox.mode(TestApp.Repo, :manual)

# Start the test endpoint
{:ok, _} = TestAppWeb.Endpoint.start_link([])

ExUnit.start()
