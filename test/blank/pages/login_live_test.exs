defmodule Blank.Pages.LoginLiveTest do
  use Blank.LiveViewCase

  setup do
    original_blank_auth = Application.get_env(:blank, :auth, [])
    original_ueberauth = Application.get_env(:ueberauth, Ueberauth, [])

    on_exit(fn ->
      Application.put_env(:blank, :auth, original_blank_auth)
      Application.put_env(:ueberauth, Ueberauth, original_ueberauth)
    end)

    :ok
  end

  test "mounting shows login form with email and password fields", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "Sign in to Blank admin"
    assert html =~ "email"
    assert html =~ "password"
    assert html =~ "Log in"
  end

  # ── Local auth toggle ──

  test "shows local form when local auth is enabled", %{conn: conn} do
    Application.put_env(:blank, :auth, local: true)

    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "Sign in to Blank admin"
    assert html =~ "email"
    assert html =~ "password"
    assert html =~ "Log in"
  end

  test "hides local form when local auth is disabled", %{conn: conn} do
    Application.put_env(:blank, :auth, local: false)

    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "Sign in to Blank admin"
    # When local auth is disabled, the email/password form should not be present
    refute html =~ ~s(<input id="login_form_email")
    refute html =~ ~s(type="password")
  end

  # ── Ueberauth provider buttons ──

  test "shows ueberauth provider buttons", %{conn: conn} do
    Application.put_env(:blank, :auth, local: true)

    Application.put_env(:ueberauth, Ueberauth,
      providers: [
        google: {Ueberauth.Strategy.Google, []},
        github: {Ueberauth.Strategy.Github, []}
      ]
    )

    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "Sign in with Google"
    assert html =~ "Sign in with Github"
    assert html =~ "/admin/auth/google"
    assert html =~ "/admin/auth/github"
  end

  test "shows ueberauth buttons without local form when local auth is disabled", %{conn: conn} do
    Application.put_env(:blank, :auth, local: false)

    Application.put_env(:ueberauth, Ueberauth,
      providers: [google: {Ueberauth.Strategy.Google, []}]
    )

    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "Sign in with Google"
    assert html =~ "/admin/auth/google"
    # Local form should not be present
    refute html =~ ~s(<input id="login_form_email")
  end

  # ── No auth methods configured ──

  test "shows guard message when no auth methods configured", %{conn: conn} do
    Application.put_env(:blank, :auth, local: false)
    Application.put_env(:ueberauth, Ueberauth, providers: [])

    {:ok, _view, html} = live(conn, "/admin/log_in")

    assert html =~ "No authentication methods are configured"
    assert html =~ "Please contact your administrator"
    # Neither local form nor ueberauth buttons should be present
    refute html =~ ~s(<input id="login_form_email")
    refute html =~ "Sign in with"
  end
end
