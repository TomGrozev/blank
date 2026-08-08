defmodule Blank.Audit.ContextTest do
  use TestAppWeb.ConnCase

  alias Blank.Audit.AuditLog
  alias Blank.Audit.Context
  alias TestApp.Accounts.User

  describe "fetch_audit_context/2" do
    test "extracts user_agent from headers", %{conn: conn} do
      conn = %{conn | req_headers: [{"user-agent", "Mozilla/5.0"}]}
      conn = Context.fetch_audit_context(conn, [])

      assert %AuditLog{} = conn.assigns.audit_context
      assert conn.assigns.audit_context.user_agent == "Mozilla/5.0"
    end

    test "extracts IP from x-forwarded-for header", %{conn: conn} do
      conn = %{conn | req_headers: [{"x-forwarded-for", "1.2.3.4"}]}
      conn = Context.fetch_audit_context(conn, [])

      assert conn.assigns.audit_context.ip_address == {1, 2, 3, 4}
    end

    test "falls back to remote_ip when no x-forwarded-for header", %{conn: conn} do
      conn = %{conn | remote_ip: {10, 0, 0, 1}, req_headers: []}
      conn = Context.fetch_audit_context(conn, [])

      assert conn.assigns.audit_context.ip_address == {10, 0, 0, 1}
    end

    test "includes current_user from conn.assigns", %{conn: conn} do
      user = %User{id: 1, email: "live@example.com"}
      conn = %{conn | assigns: Map.put(conn.assigns, :current_user, user)}
      conn = Context.fetch_audit_context(conn, [])

      assert conn.assigns.audit_context.user == user
    end

    test "prefers x-forwarded-for over remote_ip", %{conn: conn} do
      conn = %{
        conn
        | remote_ip: {10, 0, 0, 1},
          req_headers: [{"x-forwarded-for", "1.2.3.4"}]
      }

      conn = Context.fetch_audit_context(conn, [])

      assert conn.assigns.audit_context.ip_address == {1, 2, 3, 4}
    end
  end

  # NOTE: on_mount/4 is not tested here because Phoenix.LiveView.get_connect_info/2
  # can only be called inside a real mount callback. The fetch_audit_context/2 plug
  # covers the same audit context building logic for Plug.Conn connections.
end
