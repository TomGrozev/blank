defmodule Blank.ExporterTest do
  use ExUnit.Case, async: true

  alias Blank.Exporter
  alias Blank.Exporters.CSV
  alias Blank.Exporters.QRCode
  alias Blank.Field
  alias Blank.Fields.QRCode, as: FieldsQRCode

  describe "exporters/0" do
    test "returns the default exporters" do
      exporters = Exporter.exporters()
      assert QRCode in exporters
      assert CSV in exporters
    end

    test "includes additional_exporters from application config" do
      # Temporarily set additional_exporters
      original = Application.get_env(:blank, :additional_exporters)

      Application.put_env(:blank, :additional_exporters, [__MODULE__.TestExporter])

      try do
        exporters = Exporter.exporters()
        assert __MODULE__.TestExporter in exporters
        assert QRCode in exporters
        assert CSV in exporters
      after
        Application.put_env(:blank, :additional_exporters, original)
      end
    end

    test "returns a list of atoms" do
      exporters = Exporter.exporters()
      assert is_list(exporters)
      assert Enum.all?(exporters, &is_atom/1)
    end
  end

  describe "behaviour callbacks" do
    test "CSV implements all required callbacks" do
      assert CSV.display?(nil) == true
      assert CSV.name() == "CSV"
      assert CSV.icon() == "hero-chart-bar"
      assert CSV.ext() == "csv"
      assert is_function(&CSV.process/2)
      assert is_function(&CSV.save/2)
    end

    test "QRCode implements all required callbacks" do
      fields = [code: %Field{key: :code, module: FieldsQRCode}]
      assert QRCode.display?(fields) == true
      assert QRCode.name() == "QR Code"
      assert QRCode.icon() == "hero-qr-code"
      assert QRCode.ext() == "zip"
      assert is_function(&QRCode.process/2)
      assert is_function(&QRCode.save/2)
    end
  end

  # A minimal test exporter used above
  defmodule TestExporter do
    @behaviour Exporter

    @impl true
    def display?(_), do: true

    @impl true
    def name, do: "Test"

    @impl true
    def icon, do: "hero-document"

    @impl true
    def ext, do: "txt"

    @impl true
    def process(item, _fields), do: [item]

    @impl true
    def save(_stream, _path), do: :ok
  end
end
