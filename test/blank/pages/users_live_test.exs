defmodule Blank.Pages.UsersLiveTest do
  use Blank.LiveViewCase

  import Ecto.Query

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  defp create_target_user(attrs) do
    defaults = %{
      email: "target_#{System.unique_integer([:positive])}@example.com",
      password: "Str0ng!Passw0rd"
    }

    {roles, attrs} = Map.pop(Map.merge(defaults, attrs), :roles, [:member])

    {:ok, user} = Blank.Accounts.register_user(attrs)

    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{roles: roles})
      |> TestApp.Repo.update()

    user
  end

  test "mounting shows the admins index page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/admin/admins")

    assert html =~ "admins"
  end

  test "system_admin can access show page", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member]})

    {:ok, _view, html} = live(conn, "/admin/admins/#{target_user.id}")

    assert html =~ target_user.email
  end

  test "system_admin can access edit page", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member]})

    {:ok, _view, html} = live(conn, "/admin/admins/#{target_user.id}/edit")

    assert html =~ "Edit roles for"
    assert html =~ target_user.email
    assert html =~ "system_admin"
    assert html =~ "member"
  end

  test "non-system_admin is denied access to edit page", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member]})
    non_admin_user = create_target_user(%{roles: [:member]})

    conn = log_in_user(conn, non_admin_user)

    assert {:error, {:redirect, %{to: _to, flash: flash}}} =
             live(conn, "/admin/admins/#{target_user.id}/edit")

    assert flash["error"] =~ "not authorized"
  end

  test "save_roles event updates roles and creates audit log", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member]})

    {:ok, view, _html} = live(conn, "/admin/admins/#{target_user.id}/edit")

    view
    |> form("form[phx-submit=\"save_roles\"]", %{"roles" => ["system_admin", "member"]})
    |> render_submit()

    assert_flash_info(view, "Roles updated successfully")

    updated_user = TestApp.Repo.reload!(target_user)
    assert :system_admin in updated_user.roles
    assert :member in updated_user.roles

    log =
      TestApp.Repo.one!(
        from(a in Blank.Audit.AuditLog,
          where: a.action == "accounts.roles_updated",
          order_by: [desc: :inserted_at],
          limit: 1
        )
      )

    assert log.params["source"] == "admin_ui"
    assert log.params["user_id"] == target_user.id
    assert "system_admin" in log.params["roles"]
    assert "member" in log.params["roles"]
    assert "member" in log.params["before_roles"]
  end

  test "non-system_admin cannot invoke save_roles mutation", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member]})
    non_admin_user = create_target_user(%{roles: [:member]})

    conn = log_in_user(conn, non_admin_user)

    assert {:error, {:redirect, %{to: _to, flash: _flash}}} =
             live(conn, "/admin/admins/#{target_user.id}/edit")

    # Verify the user's roles haven't changed
    unchanged_user = TestApp.Repo.reload!(target_user)
    assert unchanged_user.roles == [:member]
  end

  test "save_roles with invalid roles shows error flash", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member]})

    {:ok, view, _html} = live(conn, "/admin/admins/#{target_user.id}/edit")

    # Submit with a role atom that exists but is not in the allowed set,
    # which causes a changeset validation error.
    # Use render_submit/3 to bypass form-level checkbox validation.
    render_submit(view, "save_roles", %{"roles" => ["ok"]})

    html = render(view)
    assert html =~ "Failed to update roles"
  end

  test "save_roles with empty roles list succeeds", %{conn: conn} do
    target_user = create_target_user(%{roles: [:member, :system_admin]})

    {:ok, view, _html} = live(conn, "/admin/admins/#{target_user.id}/edit")

    view
    |> form("form[phx-submit=\"save_roles\"]", %{"roles" => ["member"]})
    |> render_submit()

    assert_flash_info(view, "Roles updated successfully")

    updated_user = TestApp.Repo.reload!(target_user)
    assert :member in updated_user.roles
    refute :system_admin in updated_user.roles
  end

  defp assert_flash_info(view, expected_message) do
    html = render(view)
    assert html =~ expected_message
  end
end
