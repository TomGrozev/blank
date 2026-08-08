defmodule Blank.Accounts.UpdateRolesTest do
  use TestApp.DataCase

  alias Blank.Accounts
  alias Blank.Audit.AuditLog

  @valid_email "user@example.com"
  @valid_password "Str0ng!Passw0rd"

  defp audit_context do
    %AuditLog{user_agent: "test", ip_address: {127, 0, 0, 1}}
  end

  defp create_user(attrs \\ %{}) do
    {:ok, user} =
      Accounts.register_user(Map.merge(%{email: @valid_email, password: @valid_password}, attrs))

    user
  end

  defp set_roles(user, roles) do
    user
    |> Ecto.Changeset.change(roles: roles)
    |> TestApp.Repo.update!()
  end

  # ── update_roles/3 ──

  describe "update_roles/3" do
    test "successful role update returns updated user with new roles" do
      user = create_user() |> set_roles([:member])

      assert {:ok, updated_user} =
               Accounts.update_roles(user, [:system_admin, :member],
                 source: "test",
                 audit_context: audit_context()
               )

      assert updated_user.roles == [:system_admin, :member]
    end

    test "audit log is created with correct action" do
      user = create_user() |> set_roles([:member])

      {:ok, _} =
        Accounts.update_roles(user, [:system_admin, :member],
          source: "test",
          audit_context: audit_context()
        )

      log =
        TestApp.Repo.one!(
          from(a in AuditLog,
            where: a.action == "accounts.roles_updated",
            order_by: [desc: :inserted_at],
            limit: 1
          )
        )

      assert log.action == "accounts.roles_updated"
    end

    test "audit log params contain user_id, roles, before_roles, and source" do
      user = create_user() |> set_roles([:member])

      {:ok, _} =
        Accounts.update_roles(user, [:system_admin, :member],
          source: "test",
          audit_context: audit_context()
        )

      log =
        TestApp.Repo.one!(
          from(a in AuditLog,
            where: a.action == "accounts.roles_updated",
            order_by: [desc: :inserted_at],
            limit: 1
          )
        )

      assert log.params["user_id"] == user.id
      assert log.params["roles"] == ["system_admin", "member"]
      assert log.params["before_roles"] == ["member"]
      assert log.params["source"] == "test"
    end

    test "invalid roles are rejected" do
      user = create_user() |> set_roles([:member])

      assert {:error, _changeset} =
               Accounts.update_roles(user, [:system_admin, :invalid_role],
                 source: "test",
                 audit_context: audit_context()
               )
    end

    test "empty roles list succeeds and leaves user with no roles" do
      user = create_user() |> set_roles([:member, :system_admin])

      assert {:ok, updated_user} =
               Accounts.update_roles(user, [],
                 source: "test",
                 audit_context: audit_context()
               )

      assert updated_user.roles == []
    end

    test "source is preserved in the audit log params" do
      user = create_user() |> set_roles([:member])

      {:ok, _} =
        Accounts.update_roles(user, [:system_admin],
          source: "admin_ui",
          audit_context: audit_context()
        )

      log =
        TestApp.Repo.one!(
          from(a in AuditLog,
            where: a.action == "accounts.roles_updated",
            order_by: [desc: :inserted_at],
            limit: 1
          )
        )

      assert log.params["source"] == "admin_ui"
    end
  end
end
