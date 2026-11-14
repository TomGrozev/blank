defmodule Blank.ExportersTest do
  use ExUnit.Case

  alias Blank.Exporters.CSV
  alias Blank.Exporters.QRCode

  describe "exporters/0" do
    test "returns the default exporters" do
      exporters = Blank.Exporters.exporters()
      assert QRCode in exporters
      assert CSV in exporters
    end

    test "includes additional_exporters from application config" do
      # Temporarily set additional_exporters
      original = Application.get_env(:blank, :additional_exporters)

      Application.put_env(:blank, :additional_exporters, [__MODULE__.TestExporter])

      try do
        exporters = Blank.Exporters.exporters()
        assert __MODULE__.TestExporter in exporters
        assert QRCode in exporters
        assert CSV in exporters
      after
        Application.put_env(:blank, :additional_exporters, original)
      end
    end

    test "returns a list of atoms" do
      exporters = Blank.Exporters.exporters()
      assert is_list(exporters)
      assert Enum.all?(exporters, &is_atom/1)
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
