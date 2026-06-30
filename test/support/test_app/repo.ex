defmodule TestApp.Repo do
  use Ecto.Repo,
    otp_app: :test_app,
    adapter: Ecto.Adapters.SQLite3,
    default_dynamic_repo: false

  @doc false
  def run_sql_sandbox_owner(_), do: :ok

  @test_db_path Path.join(System.tmp_dir!(), "blank_test.sqlite3")

  def test_db_path, do: @test_db_path

  def init(_type, config) do
    config =
      config
      |> Keyword.put_new(:database, @test_db_path)
      |> Keyword.put(:pool, Ecto.Adapters.SQL.Sandbox)
      |> Keyword.put(:pubsub_server, Blank.PubSub)

    {:ok, config}
  end
end
