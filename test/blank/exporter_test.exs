defmodule Blank.ExporterTest do
  use ExUnit.Case, async: true

  describe "exporters/0" do
    test "returns the default exporters" do
      exporters = Blank.Exporter.exporters()
      assert Blank.Exporters.QRCode in exporters
      assert Blank.Exporters.CSV in exporters
    end

    test "includes additional_exporters from application config" do
      # Temporarily set additional_exporters
      original = Application.get_env(:blank, :additional_exporters)

      Application.put_env(:blank, :additional_exporters, [__MODULE__.TestExporter])

      try do
        exporters = Blank.Exporter.exporters()
        assert __MODULE__.TestExporter in exporters
        assert Blank.Exporters.QRCode in exporters
        assert Blank.Exporters.CSV in exporters
      after
        Application.put_env(:blank, :additional_exporters, original)
      end
    end

    test "returns a list of atoms" do
      exporters = Blank.Exporter.exporters()
      assert is_list(exporters)
      assert Enum.all?(exporters, &is_atom/1)
    end
  end

  describe "behaviour callbacks" do
    test "CSV implements all required callbacks" do
      assert Blank.Exporters.CSV.display?(nil) == true
      assert Blank.Exporters.CSV.name() == "CSV"
      assert Blank.Exporters.CSV.icon() == "hero-chart-bar"
      assert Blank.Exporters.CSV.ext() == "csv"
      assert is_function(&Blank.Exporters.CSV.process/2)
      assert is_function(&Blank.Exporters.CSV.save/2)
    end

    test "QRCode implements all required callbacks" do
      fields = [code: %Blank.Field{key: :code, module: Blank.Fields.QRCode}]
      assert Blank.Exporters.QRCode.display?(fields) == true
      assert Blank.Exporters.QRCode.name() == "QR Code"
      assert Blank.Exporters.QRCode.icon() == "hero-qr-code"
      assert Blank.Exporters.QRCode.ext() == "zip"
      assert is_function(&Blank.Exporters.QRCode.process/2)
      assert is_function(&Blank.Exporters.QRCode.save/2)
    end
  end

  # A minimal test exporter used above
  defmodule TestExporter do
    @behaviour Blank.Exporter

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
