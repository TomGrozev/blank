defmodule Blank.Pages.ProfileLiveTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  test "mounting shows the password change form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/profile")
    assert html =~ "Account Settings"
    assert html =~ "Current password"
    assert html =~ "New password"
  end
end
