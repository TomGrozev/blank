defmodule Blank.Pages.ProfileLiveTest do
  use Blank.LiveViewCase

  alias Blank.Accounts

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  test "mounting shows the password change form for local users", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/profile")
    assert html =~ "Account Settings"
    assert html =~ "Current password"
    assert html =~ "New password"
  end

  # ── Ueberauth user profile ──

  describe "ueberauth user profile" do
    setup %{conn: conn} do
      # Create a ueberauth user
      {:ok, ueberauth_user} =
        Accounts.create_ueberauth_user(%{
          email: "oauth_profile@example.com",
          name: "OAuth Profile User",
          provider: "google",
          external_uid: "google_uid_12345"
        })

      # Re-log in as the ueberauth user
      token = Accounts.generate_user_session_token(ueberauth_user)
      conn = Plug.Test.init_test_session(conn, %{user_token: token})

      {:ok, conn: conn, ueberauth_user: ueberauth_user}
    end

    test "shows identity card for ueberauth users", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/profile")

      assert html =~ "Account Settings"
      assert html =~ "Manage your account"
      assert html =~ "Identity Provider"
      assert html =~ "Google"
      assert html =~ "google_uid_12345"
      assert html =~ "oauth_profile@example.com"
      assert html =~ "OAuth Profile User"
    end

    test "shows identity provider management message", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/profile")

      assert html =~ "Your account is managed by"
      assert html =~ "Google"
      assert html =~ "Password changes must be made through your identity provider"
    end

    test "does not show password form for ueberauth users", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/profile")

      refute html =~ "Current password"
      refute html =~ "New password"
      refute html =~ "Change Password"
    end
  end
end
