defmodule Blank.Exporters.QRCode do
  alias Blank.Utils.QRCode

  @behaviour Blank.Exporter

  @impl true
  def display?(fields) do
    Enum.any?(fields, fn {_, %{module: mod}} -> mod == Blank.Fields.QRCode end)
  end

  @impl true
  def name, do: "QR Code"

  @impl true
  def icon, do: "hero-qr-code"

  @impl true
  def ext, do: "zip"

  @impl true
  def process(item, fields) do
    code_fields =
      fields
      |> Stream.filter(fn {_, %{module: mod}} ->
        mod == Blank.Fields.QRCode
      end)
      |> Enum.map(&elem(&1, 0))

    for field <- code_fields do
      code = Map.get(item, field)

      path = Path.join(Atom.to_string(field), "#{code}.png") |> String.to_charlist()

      content = QRCode.png(code)
      {path, content}
    end
  end

  @impl true
  def save(stream, path) do
    files =
      stream
      |> Enum.to_list()
      |> List.flatten()

    filename = Path.basename(path) |> String.to_charlist()

    with {:ok, {_filename, content}} <- :zip.create(filename, files, [:memory]) do
      File.write(path, content, [:binary])
    end
  end
end
