defmodule Blank.Exporter do
  alias Blank.Context

  @exporters [
    Blank.Exporters.QRCode,
    Blank.Exporters.CSV
  ]

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

  This is the icon displayed on the export button.
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
  @callback process(item :: map(), fields :: [{atom(), Blank.Schema.t()}]) :: list()

  @doc """
  Saves the export file

  Takes the streamed output, the location for the file to be saved and the name
  of the file to be saved. The function should return the path where the files
  is saved.
  """
  @callback save(stream :: Stream.t(), path :: Path.t()) :: :ok | {:error, any()}

  @optional_callbacks icon: 0

  @doc """
  Returns the enabled exporters
  """
  @spec exporters() :: [atom()]
  def exporters do
    @exporters ++ Application.get_env(:blank, :additional_exporters, [])
  end

  @doc """
  Exports using an exporter
  """
  def export(exporter, repo, schema, fields) do
    mod = String.to_existing_atom(exporter)
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
