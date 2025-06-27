defmodule Blank.Exporter do
  @exporters [
    Blank.Exporters.QRCode,
    Blank.Exporters.CSV
  ]

  @moduledoc """
  Exports a model's data into specific formats

  This module will use an exporter module (a module that implements the behaviour
  in this module) to export a schema's data into some output format.

  The built-in exporters are:
  #{Enum.map_join(@exporters, "\n", &"  * #{&1}")}

  ## Custom Exporters

  You can create your own custom exporter by implementing the behaviour of this
  module. In order to make sure your config option displays in the export module
  you will need to add your custom exporter to the `:additional_exporters`
  config option. For example:

      config :blank,
        ...
        additional_exporters: [MyApp.TextExporter]
        ...

  ### Example

  Below is an example exporter that exports data into text.

      defmodule MyApp.TextExporter do
        @behaviour Blank.Exporter

        @impl true
        def display?(_), do: true

        @impl true
        def name, do: "Text"

        @impl true
        def icon, do: "hero-document-text"

        @impl true
        def ext, do: "txt"

        @impl true
        def process(item, fields) do
          item
          |> Map.from_struct()
          |> Stream.map(fn {k, v} ->
            case Keyword.fetch(fields, k) do
              {:ok, %{display_field: nil}} ->
                {k, v}

              {:ok, %{display_field: display}} ->
                {k, get_val(v, display)}

              :error ->
                nil
            end
          end)
          |> Stream.reject(&is_nil/1)
          |> Stream.map(fn {k, v} -> "\#{k}: \#{convert_string(v)}" end)
        end

        defp get_val(val, key) when is_list(val), do: Enum.map_join(val, ", ", &get_val(&1, key))

        defp get_val(%{} = val, key), do: Map.get(val, key)

        defp get_val(val, _), do: val

        defp convert_string(list) when is_list(list) do
          Enum.map(list, &convert_string/1)
        end

        defp convert_string(%DateTime{} = date) do
          DateTime.to_iso8601(date)
        end

        defp convert_string(other), do: other

        @impl true
        def save(stream, path) do
          stream
          |> Enum.join("\\n")
          |> Stream.into(File.stream!(path, [:write, :utf8]))
          |> Stream.run()

          :ok
        end
      end
  """

  alias Blank.Context

  @doc """
  Whether the exporter should be shown

  Accepts the fields definitions keyword list and returns a boolean whether it
  should be displayed.
  """
  @callback display?(fields :: [{atom(), Blank.Schema.t()}]) :: boolean()

  @doc """
  The name of the exporter

  This is what is displayed on the export button.
  """
  @callback name() :: String.t()

  @doc """
  The name of the icon to use

  This is the hero icon displayed on the export button.
  """
  @callback icon() :: String.t()

  @doc """
  The file extension of the export file

  For example, this could be zip, csv, png, etc.
  """
  @callback ext() :: String.t()

  @doc """
  Process each item

  This function is applied for each record in the database. This function will
  be streamed and won't be processed until actioned in the `save/3` function.
  """
  @callback process(item :: map(), fields :: [{atom(), Blank.Schema.t()}]) ::
              Enumerable.t()

  @doc """
  Saves the export file

  Takes the streamed output, the location for the file to be saved and the name
  of the file to be saved. The function should return the path where the
  file is to be saved.
  """
  @callback save(stream :: Enumerable.t(), path :: Path.t()) :: :ok | {:error, any()}

  @optional_callbacks icon: 0

  @doc """
  Returns the enabled exporters

  To add additional exporters you need to add them as a list to your application
  config by setting the `:additional_exporters` option to a list of custom
  exporters.

      config :blank,
        ...
        additional_exporters: [MyApp.CustomExporter]
        ...
  """
  @spec exporters() :: [atom()]
  def exporters do
    @exporters ++ Application.get_env(:blank, :additional_exporters, [])
  end

  @doc """
  Exports using an exporter

  Will use an exporter module to export all data of a schema model.

  ## Parameters

    * `exporter` - the exporter module to use to export the data
    * `repo` - the repo to use to query
    * `schema` - the schema used to query the data
    * `fields` - the fields to use for the query
  """
  @spec export(String.t() | module(), module(), module(), [Blank.Field.t()]) ::
          {:ok, String.t()}
          | {:error, String.t()}
  def export(exporter, repo, schema, fields) when is_binary(exporter) do
    mod = String.to_existing_atom(exporter)
    export(mod, repo, schema, fields)
  end

  def export(mod, repo, schema, fields)
      when is_atom(mod) and
             is_atom(repo) and is_atom(schema) and is_list(fields) do
    name = Phoenix.Naming.resource_name(mod)
    ext = apply(mod, :ext, [])

    id = Ecto.UUID.generate()
    filename = "export_#{name}_#{id}.#{ext}"

    stream =
      Context.list_schema(repo, schema, fields)
      |> Stream.map(&apply(mod, :process, [&1, fields]))

    with tmp_dir when not is_nil(tmp_dir) <- System.tmp_dir(),
         dir = Path.join(tmp_dir, "blank"),
         :ok <- File.mkdir_p(dir),
         path = Path.join(dir, filename),
         :ok <- apply(mod, :save, [stream, path]) do
      Blank.DownloadAgent.add(id, path)
    else
      nil -> {:error, "cannot create temporary directory"}
    end
  end
end
