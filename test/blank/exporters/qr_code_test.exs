defmodule Blank.Exporters.QRCodeTest do
  use ExUnit.Case, async: false

  describe "name/0" do
    test "returns QR Code" do
      assert Blank.Exporters.QRCode.name() == "QR Code"
    end
  end

  describe "icon/0" do
    test "returns hero-qr-code" do
      assert Blank.Exporters.QRCode.icon() == "hero-qr-code"
    end
  end

  describe "ext/0" do
    test "returns zip" do
      assert Blank.Exporters.QRCode.ext() == "zip"
    end
  end

  describe "display?/1" do
    test "returns true when fields contain a QRCode field" do
      fields = [
        barcode: %Blank.Field{key: :barcode, module: Blank.Fields.QRCode, path: "/items"}
      ]

      assert Blank.Exporters.QRCode.display?(fields) == true
    end

    test "returns false when fields have no QRCode fields" do
      fields = [
        title: %Blank.Field{key: :title, module: Blank.Fields.Text}
      ]

      assert Blank.Exporters.QRCode.display?(fields) == false
    end

    test "returns false for empty fields" do
      assert Blank.Exporters.QRCode.display?([]) == false
    end
  end

  describe "process/2" do
    test "returns QR code PNG content for QRCode fields" do
      item = %{barcode: "ABC123", title: "Test"}

      fields = [
        barcode: %Blank.Field{key: :barcode, module: Blank.Fields.QRCode, path: "/"}
      ]

      result = Blank.Exporters.QRCode.process(item, fields)

      assert is_list(result)
      assert [{path, content}] = result
      assert path == ~c"barcode/ABC123.png"
      assert is_binary(content)
      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = content
    end

    test "returns empty list when no QRCode fields present" do
      item = %{title: "Test"}

      fields = [
        title: %Blank.Field{key: :title, module: Blank.Fields.Text}
      ]

      result = Blank.Exporters.QRCode.process(item, fields)
      assert result == []
    end
  end

  describe "save/2" do
    test "writes a valid zip file" do
      path =
        Path.join(
          System.tmp_dir!(),
          "blank_qrcode_test_#{System.unique_integer([:positive])}.zip"
        )

      on_exit(fn -> File.rm(path) end)

      stream = [[{~c"barcode/ABC123.png", <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>}]]

      assert :ok = Blank.Exporters.QRCode.save(stream, path)

      assert File.exists?(path)
      {:ok, files} = :zip.unzip(String.to_charlist(path), [:memory])

      assert length(files) == 1
      [{filename, _content}] = files
      assert to_string(filename) =~ "ABC123"
    end

    test "handles empty stream" do
      path =
        Path.join(
          System.tmp_dir!(),
          "blank_qrcode_empty_#{System.unique_integer([:positive])}.zip"
        )

      on_exit(fn -> File.rm(path) end)

      assert :ok = Blank.Exporters.QRCode.save([], path)
      assert File.exists?(path)
    end
  end
end
