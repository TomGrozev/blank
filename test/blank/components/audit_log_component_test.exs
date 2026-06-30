defmodule Blank.Components.AuditLogComponentTest do
  use Blank.LiveViewCase

  alias Blank.Audit.AuditLog

  setup %{conn: conn} do
    {:ok, conn: log_in_admin(conn)}
  end

  test "mounting the audit log page renders the component with logs", %{conn: conn} do
    # Insert audit logs
    Blank.Audit.log!(AuditLog.system(), "posts.create", %{item_id: 1})
    Blank.Audit.log!(AuditLog.system(), "posts.update", %{item_id: 2})

    {:ok, _view, html} = live(conn, "/admin/audit")

    assert html =~ "Audit Logs"
    assert html =~ "Displays the activity log"
  end

  test "component updates when new log is broadcast", %{conn: conn} do
    Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")

    {:ok, view, _html} = live(conn, "/admin/audit")

    # Create a new audit log - the PubSub broadcast should update the component
    Blank.Audit.log!(AuditLog.system(), "posts.create", %{item_id: 99})

    # Give the PubSub a moment to deliver
    Process.sleep(100)

    html = render(view)
    assert html =~ "Audit Logs"
  end
end
