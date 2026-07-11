defmodule Mix.Tasks.Blank.InstallTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Blank.Install

  setup do
    dir = Path.join(System.tmp_dir!(), "blank_install_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    on_exit(fn ->
      File.rm_rf(dir)
    end)

    %{tmp_dir: dir}
  end

  defp create_endpoint_source(dir, content) do
    # Create a source file and compile it to get a module whose
    # __info__(:compile)[:source] points to this file.
    source_file = Path.join(dir, "endpoint.ex")
    File.write!(source_file, content)
    [{mod, _}] = Code.compile_file(source_file)
    {mod, source_file}
  end

  describe "run/1 with invalid adapter" do
    test "produces an error message", %{tmp_dir: dir} do
      {_mod, _source_file} =
        create_endpoint_source(dir, """
          defmodule InstallTestInvalidAdapterEndpoint do
            use Phoenix.Endpoint, otp_app: :test_app

            socket "/live", Phoenix.LiveView.Socket,
              websocket: [connect_info: [:uri]]
          end
        """)

      original_endpoint = Application.get_env(:blank, :endpoint)
      Application.put_env(:blank, :endpoint, InstallTestInvalidAdapterEndpoint)

      on_exit(fn ->
        Application.put_env(:blank, :endpoint, original_endpoint)
      end)

      # Capture both stdout and stderr
      output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Install.run(["--adapter", "invalid_adapter"])
        end)

      assert output =~ "invalid adapter" or output =~ "failed to install"
    end
  end

  describe "run/1 with valid adapter" do
    test "adds audit socket options to endpoint source", %{tmp_dir: dir} do
      {mod, source_file} =
        create_endpoint_source(dir, """
          defmodule InstallTestAuditEndpoint do
            use Phoenix.Endpoint, otp_app: :test_app

            socket "/live", Phoenix.LiveView.Socket,
              websocket: [connect_info: [:uri]]
          end
        """)

      original_endpoint = Application.get_env(:blank, :endpoint)
      Application.put_env(:blank, :endpoint, mod)

      on_exit(fn ->
        Application.put_env(:blank, :endpoint, original_endpoint)
      end)

      Mix.shell(Mix.Shell.Process)

      Install.run(["--adapter", "ecto_sql"])

      endpoint_content = File.read!(source_file)
      assert endpoint_content =~ "peer_data"
      assert endpoint_content =~ "x_headers"
      assert endpoint_content =~ "user_agent"
    end

    test "copies migrations to the specified path", %{tmp_dir: dir} do
      {mod, _source_file} =
        create_endpoint_source(dir, """
          defmodule InstallTestMigrationEndpoint do
            use Phoenix.Endpoint, otp_app: :test_app

            socket "/live", Phoenix.LiveView.Socket,
              websocket: [connect_info: [:uri]]
          end
        """)

      original_endpoint = Application.get_env(:blank, :endpoint)
      Application.put_env(:blank, :endpoint, mod)

      migrations_dir = Path.join(dir, "priv/repo/migrations")
      File.mkdir_p!(migrations_dir)

      on_exit(fn ->
        Application.put_env(:blank, :endpoint, original_endpoint)
      end)

      Mix.shell(Mix.Shell.Process)

      Install.run([
        "--adapter",
        "ecto_sql",
        "--migrations-path",
        migrations_dir
      ])

      copied_files = File.ls!(migrations_dir)
      assert not Enum.empty?(copied_files), "Expected migrations to be copied"
      assert Enum.any?(copied_files, &String.contains?(&1, "create_users_auth_tables"))
      assert Enum.any?(copied_files, &String.contains?(&1, "create_audit_log"))
    end

    test "default adapter is ecto_sql when not specified", %{tmp_dir: dir} do
      {mod, _source_file} =
        create_endpoint_source(dir, """
          defmodule InstallTestDefaultAdapterEndpoint do
            use Phoenix.Endpoint, otp_app: :test_app

            socket "/live", Phoenix.LiveView.Socket,
              websocket: [connect_info: [:uri]]
          end
        """)

      original_endpoint = Application.get_env(:blank, :endpoint)
      Application.put_env(:blank, :endpoint, mod)

      migrations_dir = Path.join(dir, "priv/repo/default_migrations")
      File.mkdir_p!(migrations_dir)

      on_exit(fn ->
        Application.put_env(:blank, :endpoint, original_endpoint)
      end)

      Mix.shell(Mix.Shell.Process)

      # No --adapter flag, should default to ecto_sql
      Install.run(["--migrations-path", migrations_dir])

      copied_files = File.ls!(migrations_dir)
      assert not Enum.empty?(copied_files)
    end
  end
end
