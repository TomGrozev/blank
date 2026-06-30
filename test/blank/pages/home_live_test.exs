defmodule Blank.Pages.HomeLiveTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  test "mounting shows the home page with dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin")

    assert html =~ "Dashboard"
    assert html =~ "Past Activity"
    assert html =~ "Active Users"
  end
end
