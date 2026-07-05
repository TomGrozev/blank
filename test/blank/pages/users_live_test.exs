defmodule Blank.Pages.UsersLiveTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  test "mounting shows the admins index page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/admins")

    assert html =~ "admins"
  end
end
