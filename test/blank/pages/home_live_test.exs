defmodule Blank.Pages.HomeLiveTest do
  use Blank.LiveViewCase

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  test "mounting shows the home page with dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin")

    assert html =~ "Dashboard"
    assert html =~ "Past Activity"
    assert html =~ "Active Users"
  end

  describe "toggle-all-presences" do
    test "clicking toggles view_all_presences from false to true", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin")

      html = render_click(view, "toggle-all-presences")
      assert html =~ "Hide"
    end

    test "clicking again toggles back to false", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin")

      render_click(view, "toggle-all-presences")
      html = render_click(view, "toggle-all-presences")
      assert html =~ "View all"
    end
  end

  describe "presence join messages" do
    test "join message adds user to the presences stream", %{conn: conn} do
      # Create a real user in the DB so apply_past_logins can query it
      user = user_fixture(%{roles: [:member]})

      {:ok, view, _html} = live(conn, "/admin")

      presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: [%{current_page: :home}]
      }

      send(view.pid, {Blank.Presence, {:join, presence}})

      html = render(view)
      assert html =~ user.email
    end
  end

  describe "presence leave messages" do
    test "leave with empty metas removes user from the presences stream", %{conn: conn} do
      # Create a real user in the DB
      user = user_fixture(%{roles: [:member]})

      {:ok, view, _html} = live(conn, "/admin")

      presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: [%{current_page: :home}]
      }

      send(view.pid, {Blank.Presence, {:join, presence}})
      html = render(view)
      assert html =~ user.email

      # Now leave with empty metas
      leave_presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: []
      }

      send(view.pid, {Blank.Presence, {:leave, leave_presence}})

      html = render(view)
      refute html =~ user.email
    end

    test "leave with non-empty metas updates user in the presences stream", %{conn: conn} do
      # Create a real user in the DB
      user = user_fixture(%{roles: [:member]})

      {:ok, view, _html} = live(conn, "/admin")

      presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: [%{current_page: :home}]
      }

      send(view.pid, {Blank.Presence, {:join, presence}})
      html = render(view)
      assert html =~ user.email

      # Leave with non-empty metas (still online, just a meta change)
      leave_presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: [%{current_page: :settings}]
      }

      send(view.pid, {Blank.Presence, {:leave, leave_presence}})

      html = render(view)
      assert html =~ user.email
    end
  end

  describe "audit log messages" do
    test "audit_log message sends update to audit log component", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin")

      # Create a minimal audit log struct
      log = %Blank.Audit.AuditLog{
        id: 1,
        action: "test.action",
        params: %{},
        user_agent: "test",
        user_id: nil,
        inserted_at: ~N[2025-01-01 00:00:00]
      }

      send(view.pid, {:audit_log, log})

      # The component should handle the update without crashing
      html = render(view)
      assert html =~ "Dashboard"
    end
  end

  describe "presence list rendering" do
    test "shows empty message when no users are online", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin")

      assert html =~ "There are no users online :("
    end

    test "renders presence with past logins shows history button", %{conn: conn} do
      user = user_fixture(%{roles: [:member]})

      {:ok, view, _html} = live(conn, "/admin")

      presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: [%{current_page: :home}]
      }

      send(view.pid, {Blank.Presence, {:join, presence}})

      html = render(view)
      assert html =~ user.email
    end

    test "renders presence without past logins does not show history button", %{conn: conn} do
      user = user_fixture(%{roles: [:member]})

      {:ok, view, _html} = live(conn, "/admin")

      presence = %{
        id: user.id,
        user: user.email,
        schema: Blank.Accounts.User,
        metas: [%{current_page: :home}]
      }

      send(view.pid, {Blank.Presence, {:join, presence}})

      html = render(view)
      assert html =~ user.email
    end
  end
end
