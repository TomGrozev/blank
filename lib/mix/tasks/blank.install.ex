defmodule Mix.Tasks.Blank.Install do
  @moduledoc """
  Installs Blank into an application

  This will add blank into your tailwind config, install required audit options
  (if enabled) and copy migrations.

  Accepts the following options:

    * `adapter` - specify the database adapter to be used.
      Accepts: ecto_sql, arango
    * `migrations_path` - path to the migrations folder (defaults to the
      priv/repo/migrations in your project directory)
  """

  use Mix.Task

  @requirements ["app.config"]

  @switches [
    migrations_path: :keep,
    adapter: :string
  ]

  @adapters [
    "ecto_sql",
    "arango"
  ]

  @impl true
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    blank_dir =
      __ENV__.file
      |> Path.dirname()
      |> Path.join("../../..")
      |> Path.expand()

    project_dir = File.cwd!()

    migrations_paths = Keyword.get_values(opts, :migrations_path)

    umbrella_migrations_path =
      Path.join(project_dir, "apps/**/priv/repo/migrations")
      |> Path.wildcard()

    migrations_paths =
      if(migrations_paths == [],
        do: [Path.join(project_dir, "priv/repo/migrations")] ++ umbrella_migrations_path,
        else: migrations_paths
      )
      |> Stream.filter(&File.exists?/1)
      |> Stream.map(&Path.relative_to(&1, project_dir, force: true))

    with :ok <- add_tailwind_files(blank_dir, project_dir),
         :ok <- add_audit_options(),
         {:ok, adapter} <- get_adapter(opts),
         :ok <- add_migrations(blank_dir, project_dir, adapter, migrations_paths) do
      Mix.Shell.IO.info("""
      \n
      Blank has been installed.

      You should now apply migrations (e.g. mix ecto.migrate).
      """)
    else
      {:error, reason} ->
        Mix.Shell.IO.error("""
        \n
        Blank failed to install.

        Reason: #{inspect(reason)}
        """)
    end
  end

  defp get_adapter(opts) do
    adapter = Keyword.get(opts, :adapter, "ecto_sql")

    if adapter in @adapters do
      Mix.Shell.IO.info(">> Using #{adapter} as the database adapter")

      {:ok, adapter}
    else
      {:error, "invalid adapter #{inspect(adapter)}, accepts: #{Enum.join(@adapters, ", ")}"}
    end
  end

  defp add_tailwind_files(blank_dir, project_dir) do
    blank_lib = Path.join(blank_dir, "lib")

    Path.join(project_dir, "**/tailwind.config.js")
    |> Path.wildcard()
    |> Enum.reduce_while(:ok, fn file, _acc ->
      case add_blank_to_tailwind(file, blank_lib) do
        {:error, reason} ->
          {:halt, {:error, reason}}

        :ok ->
          Mix.Shell.IO.info(">> Added blank dir to tailwind config in #{file}")
          {:cont, :ok}
      end
    end)
  end

  @content_regex ~r/content: \[(.*?)\]/is
  defp add_blank_to_tailwind(file, blank_dir) do
    blank_path =
      blank_dir
      |> Path.relative_to(Path.dirname(file), force: true)
      |> Path.join("**/*.*ex")

    with {:ok, content} <- File.read(file),
         true <- Regex.match?(@content_regex, content) do
      new_content =
        Regex.replace(@content_regex, content, fn _, inner ->
          replace_tailwind_content(inner, blank_path, file)
        end)

      File.write(file, new_content)
    else
      false -> {:error, "could not read content in '#{file}'"}
    end
  end

  defp replace_tailwind_content(inner, blank_path, file) do
    with [first_content | _] = content <- String.split(inner, ","),
         [_, prefix] <- Regex.run(~r/(\n?\s*).*/, first_content) do
      path = "#{prefix}\"#{blank_path}\""

      if(path in content, do: content, else: [path | content])
      |> Enum.join(",")
      |> then(&"content: [#{&1}]")
    else
      nil -> {:error, "could not read content in '#{file}'"}
    end
  end

  @socket_regex ~r/\[connect_info: (\[.*?\])\]/is
  defp add_audit_options do
    # TODO: Add optional audit config option
    endpoint = Application.fetch_env!(:blank, :endpoint)
    Code.ensure_compiled!(endpoint)

    source =
      endpoint.__info__(:compile)
      |> Keyword.fetch!(:source)

    with {:ok, content} <- File.read(source),
         true <- Regex.match?(@socket_regex, content),
         new_content =
           Regex.replace(@socket_regex, content, fn _, inner ->
             replace_socket_content(inner, source)
           end),
         :ok <- File.write(source, new_content) do
      Mix.Shell.IO.info(">> Added audit socket requirements to endpoint file: #{source}")

      :ok
    else
      false -> {:error, "could not read content in '#{source}'"}
    end
  end

  defp replace_socket_content(inner, file) do
    case Code.string_to_quoted(inner) do
      {:ok, quoted} ->
        [:peer_data, :x_headers, :user_agent | quoted]
        |> Enum.uniq()
        |> Macro.to_string()
        |> then(&"[connect_info: #{&1}]")

      nil ->
        {:error, "could not replace socket info in '#{file}'"}
    end
  end

  defp add_migrations(blank_dir, project_dir, adapter, project_migration_paths) do
    migration_path = Path.join(blank_dir, "priv/repo/migrations_#{adapter}")

    Enum.reduce_while(project_migration_paths, :ok, fn
      path, _ ->
        path =
          Path.join(project_dir, path)
          |> Path.expand()

        case File.cp_r(migration_path, path) do
          {:ok, _} ->
            Mix.Shell.IO.info(">> Added blank migrations to #{path}")

            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end
end
