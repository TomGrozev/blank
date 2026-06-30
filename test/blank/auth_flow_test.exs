defmodule Blank.AuthFlowTest do
  use Blank.ConnCase

  alias Blank.Accounts
  alias Blank.Plugs.Auth

  @valid_email "admin@example.com"
  @valid_password "Str0ng!Passw0rd"

  setup %{conn: conn} do
    {:ok, admin} = Accounts.register_admin(%{email: @valid_email, password: @valid_password})
    %{conn: conn, admin: admin}
  end

  # ── SessionController.create/2 ──

  describe "SessionController.create/2" do
    test "with valid credentials redirects to admin home and sets session token", %{conn: conn} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "admin" => %{"email" => @valid_email, "password" => @valid_password}
        })

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"

      # The session should contain admin_token
      assert get_session(conn, :admin_token)
    end

    test "with invalid credentials redirects to /log_in with error flash", %{conn: conn} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "admin" => %{"email" => @valid_email, "password" => "wrongpassword"}
        })

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end

    test "with invalid email redirects to /log_in", %{conn: conn} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "admin" => %{"email" => "unknown@example.com", "password" => @valid_password}
        })

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end
  end

  # ── SessionController.delete/2 ──

  describe "SessionController.delete/2" do
    test "logs out and redirects to prefix", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> delete("/admin/log_out")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"

      # Session should be cleared — trying to access protected page should redirect
      conn2 =
        conn
        |> recycle()
        |> get("/admin")

      assert %{status: 302} = conn2
    end
  end

  # ── Auth.fetch_current_admin/2 ──

  describe "Auth.fetch_current_admin/2" do
    test "with a valid session token, assigns :current_admin", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"
    end

    test "with no token, :current_admin is nil and redirects to log_in", %{conn: conn} do
      conn = get(conn, "/admin")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end
  end

  # ── Auth.redirect_if_admin_is_authenticated/2 ──

  describe "Auth.redirect_if_admin_is_authenticated/2" do
    test "when no admin, allows through to login page", %{conn: conn} do
      conn = get(conn, "/admin/log_in")
      assert html_response(conn, 200) =~ "Sign in to Blank admin"
    end

    test "when admin is authenticated, redirects to signed_in_path", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> get("/admin/log_in")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"
    end
  end

  # ── Auth.require_authenticated_admin/2 ──

  describe "Auth.require_authenticated_admin/2" do
    test "when no admin, redirects to log_in", %{conn: conn} do
      conn = get(conn, "/admin/settings")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin/log_in"
    end

    test "when admin is authenticated, allows through", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"
    end
  end

  # ── Auth.log_in/3 ──

  describe "Auth.log_in/3" do
    test "creates a session token and redirects to signed_in_path", %{conn: conn, admin: admin} do
      # Use the router to set up a conn with proper session and pipeline
      conn =
        conn
        |> post("/admin/log_in", %{
          "admin" => %{"email" => @valid_email, "password" => @valid_password}
        })

      assert %{status: 302} = conn
      assert get_session(conn, :admin_token)
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"
    end

    test "with remember_me cookie", %{conn: conn, admin: admin} do
      conn =
        conn
        |> post("/admin/log_in", %{
          "admin" => %{
            "email" => @valid_email,
            "password" => @valid_password,
            "remember_me" => "true"
          }
        })

      assert %{status: 302} = conn
      assert get_session(conn, :admin_token)

      # Should have set the remember me cookie
      conn_cookies = Plug.Conn.fetch_cookies(conn)
      assert conn_cookies.cookies["_blank_admin_remember_me"]
    end
  end

  # ── Auth.log_out/1 ──

  describe "Auth.log_out/1" do
    test "deletes the token and redirects to prefix", %{conn: conn, admin: admin} do
      # Log in through the router first
      conn =
        conn
        |> log_in_admin(admin)
        |> get("/admin/settings")

      assert html_response(conn, 200) =~ "Settings"

      # Now log out via the router
      conn =
        conn
        |> recycle()
        |> log_in_admin(admin)
        |> delete("/admin/log_out")

      assert %{status: 302} = conn
      location = get_resp_header(conn, "location") |> List.first()
      assert location == "/admin"
    end
  end
end
