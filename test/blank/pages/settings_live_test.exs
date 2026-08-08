defmodule Blank.Pages.SettingsLiveTest do
  use Blank.LiveViewCase

  alias Blank.Audit.AuditLog

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  test "mounting shows the danger zone with reset button", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/settings")

    assert html =~ "Settings"
    assert html =~ "Danger Zone"
    assert html =~ "Reset ALL logs"
  end

  test "clicking reset-audit-logs deletes all audit logs", %{conn: conn} do
    context = AuditLog.system()
    Blank.Audit.log!(context, "posts.create", %{item_id: 1})
    Blank.Audit.log!(context, "posts.create", %{item_id: 2})

    {:ok, view, _html} = live(conn, "/admin/settings")

    view
    |> element("button", "Reset all")
    |> render_click()

    remaining_logs = Blank.Audit.list_all()
    actions = Enum.map(remaining_logs, & &1.action)
    refute "posts.create" in actions
  end
end
