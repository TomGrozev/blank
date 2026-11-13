defmodule Blank.Pages.AuditLogLiveTest do
  use Blank.LiveViewCase

  alias Blank.Audit.AuditLog

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  test "mounting shows the audit log component", %{conn: conn} do
    # Insert an audit log using a valid action format (schema.action)
    Blank.Audit.log!(AuditLog.system(), "posts.create", %{item_id: 1})

    {:ok, _view, html} = live(conn, "/admin/audit")

    assert html =~ "Audit Logs"
    assert html =~ "Displays the activity log"
  end

  describe "put_time_zone/1" do
    test "with local time zone enabled assigns the browser time zone", %{conn: conn} do
      conn = with_browser_time_zone(conn)
      {:ok, view, _html} = live(conn, "/admin/audit")

      assert :sys.get_state(view.pid).socket.assigns.time_zone == "America/New_York"
    end
  end
end
