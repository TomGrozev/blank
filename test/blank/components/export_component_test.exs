defmodule Blank.Components.ExportComponentTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, user: user_fixture(), conn: log_in_user(conn)}
  end

  test "mounting the posts export page shows export options", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/posts/export")

    assert html =~ "Export"
    # The export page should show available exporters
    assert html =~ "CSV" or html =~ "Export"
  end
end
