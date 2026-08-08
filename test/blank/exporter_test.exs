defmodule Blank.ExporterTest do
  use TestApp.DataCase

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

  describe "export/4" do
    setup do
      post1 = Repo.insert!(%Post{title: "First Post", body: "Body one", published: true})
      post2 = Repo.insert!(%Post{title: "Second Post", body: "Body two", published: false})

      fields = [
        title: %Field{key: :title, module: Blank.Fields.Text, display_field: nil},
        body: %Field{key: :body, module: Blank.Fields.Text, display_field: nil}
      ]

      %{posts: [post1, post2], fields: fields}
    end

    test "exports CSV with atom exporter and returns {:ok, download_id}", %{fields: fields} do
      assert {:ok, download_id} = Exporter.export(CSV, TestApp.Repo, Post, fields)
      assert is_binary(download_id)

      # Retrieve the actual file path from DownloadAgent
      assert {:ok, path} = Blank.DownloadAgent.get(download_id)
      assert File.exists?(path)
      assert Path.extname(path) == ".csv"

      content = File.read!(path)
      lines = String.split(content, "\n", trim: true)

      # Header + 2 data rows
      assert length(lines) == 3
      assert hd(lines) =~ "title"
      assert hd(lines) =~ "body"

      # Verify data rows contain our posts
      assert Enum.any?(lines, &(&1 =~ "First Post"))
      assert Enum.any?(lines, &(&1 =~ "Second Post"))
    end

    test "registers the file with DownloadAgent and retrievable", %{fields: fields} do
      assert {:ok, download_id} = Exporter.export(CSV, TestApp.Repo, Post, fields)

      # Verify the file is registered in DownloadAgent
      assert {:ok, path} = Blank.DownloadAgent.get(download_id)
      assert File.exists?(path)
    end

    test "exports CSV with binary exporter string", %{fields: fields} do
      exporter_string = "Elixir.Blank.Exporters.CSV"

      assert {:ok, download_id} = Exporter.export(exporter_string, TestApp.Repo, Post, fields)
      assert is_binary(download_id)

      assert {:ok, path} = Blank.DownloadAgent.get(download_id)
      assert File.exists?(path)
      assert Path.extname(path) == ".csv"

      content = File.read!(path)
      assert content =~ "First Post"
      assert content =~ "Second Post"
    end

    test "generates unique download IDs for each export", %{fields: fields} do
      {:ok, id1} = Exporter.export(CSV, TestApp.Repo, Post, fields)
      {:ok, id2} = Exporter.export(CSV, TestApp.Repo, Post, fields)

      assert id1 != id2
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
