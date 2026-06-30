defmodule Blank.Components.ImportComponentTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, admin: admin_fixture(), conn: log_in_admin(conn)}
  end

  test "mounting the posts import page shows the upload form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/posts/import")

    assert html =~ "Import"
    assert html =~ "CSV"
    assert html =~ "upload" or html =~ "Upload"
  end
end
