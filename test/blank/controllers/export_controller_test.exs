defmodule Blank.Controllers.ExportControllerTest do
  use Blank.ConnCase

  setup %{conn: conn} do
    {:ok, user: user_fixture(), conn: log_in_user(conn)}
  end

  describe "download/2" do
    test "with a valid id returns the file", %{conn: conn} do
      # Create a temporary file and register it with the DownloadAgent
      dir =
        Path.join(System.tmp_dir!(), "blank_export_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      path = Path.join(dir, "test_export.csv")
      File.write!(path, "id,name\n1,Test")

      on_exit(fn -> File.rm_rf(dir) end)

      id = "test-download-#{System.unique_integer([:positive])}"
      {:ok, ^id} = Blank.DownloadAgent.add(id, path)

      conn = get(conn, "/admin/download", %{"id" => id})

      assert conn.status == 200
    end

    test "with an invalid id returns 404", %{conn: conn} do
      conn = get(conn, "/admin/download", %{"id" => "nonexistent-id"})

      assert conn.status == 404
      assert conn.resp_body =~ "404"
    end
  end

  describe "qr_code/2" do
    test "with a code and path returns a PNG", %{conn: conn} do
      conn = get(conn, "/admin/qrcode", %{"code" => "test123", "path" => "/some/path"})

      assert conn.status == 200
      # QR code generates PNG binary data
      assert conn.resp_body != nil
      assert byte_size(conn.resp_body) > 0
    end

    test "without code and path returns 404", %{conn: conn} do
      conn = get(conn, "/admin/qrcode")

      assert conn.status == 404
      assert conn.resp_body =~ "404"
    end
  end
end
