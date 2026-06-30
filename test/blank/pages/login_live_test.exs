defmodule Blank.Pages.LoginLiveTest do
  use Blank.LiveViewCase

  test "mounting shows login form with email and password fields", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "Sign in to Blank admin"
    assert html =~ "email"
    assert html =~ "password"
    assert html =~ "Log in"
  end
end
