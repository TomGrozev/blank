defmodule Blank.Pages.AuditLogLiveTest do
  use Blank.LiveViewCase

  alias Blank.Audit.AuditLog

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  test "mounting shows the audit log component", %{conn: conn} do
    # Insert an audit log using a valid action format (schema.action)
    Blank.Audit.log!(AuditLog.system(), "posts.create", %{item_id: 1})

    {:ok, _view, html} = live(conn, "/admin/audit")

    assert html =~ "Audit Logs"
    assert html =~ "Displays the activity log"
  end
end
