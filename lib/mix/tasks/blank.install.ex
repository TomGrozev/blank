defmodule Mix.Tasks.Blank.Install do
  @moduledoc """
  Installs Blank
  """

  use Mix.Task

  @impl true
  def run(_args) do
    blank_dir =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("../../..")
      |> Path.expand()

    project_dir = File.cwd!()

    # Add migrations
    migration_path = Path.join(blank_dir, "priv/repo/migrations")
    File.cp_r(migration_path, Path.join(project_dir, "priv/repo/migrations"))
    Mix.Shell.IO.info(">> Added admins user migrations")

    Mix.Shell.IO.info("""
    \n
    Blank has been installed.

    You should now apply migrations (e.g. mix ecto.migrate).
    """)
  end
end
