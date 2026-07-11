defmodule Blank.Audit.AuditLogTest do
  use TestApp.DataCase

  alias Blank.Audit.AuditLog

  describe "system/0" do
    test "returns a struct with user: nil and user_agent: SYSTEM" do
      log = AuditLog.system()

      assert %AuditLog{} = log
      assert log.user == nil
      assert log.user_agent == "SYSTEM"
      assert log.params == %{}
    end
  end

  describe "build!/3 with valid actions" do
    test "app.foo always passes with any params" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "app.foo", %{anything: true, nested: %{key: "val"}})

      assert log.action == "app.foo"
      assert log.params == %{anything: true, nested: %{key: "val"}}
    end

    test "accounts.login with email and type" do
      context = AuditLog.system()

      log =
        AuditLog.build!(context, "accounts.login", %{
          email: "user@example.com",
          type: "password",
          provider: nil
        })

      assert log.action == "accounts.login"
      assert log.params == %{email: "user@example.com", type: "password", provider: nil}
    end

    test "posts.create with item_id" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "posts.create", %{item_id: 42})

      assert log.action == "posts.create"
      assert log.params == %{item_id: 42}
    end

    test "posts.update with item_id" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "posts.update", %{item_id: 7})

      assert log.action == "posts.update"
      assert log.params == %{item_id: 7}
    end

    test "posts.delete with item_id" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "posts.delete", %{item_id: 3})

      assert log.action == "posts.delete"
      assert log.params == %{item_id: 3}
    end

    test "posts.create_multiple with item_ids" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "posts.create_multiple", %{item_ids: [1, 2, 3]})

      assert log.action == "posts.create_multiple"
      assert log.params == %{item_ids: [1, 2, 3]}
    end

    test "posts.update_multiple with item_ids" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "posts.update_multiple", %{item_ids: [4, 5]})

      assert log.action == "posts.update_multiple"
      assert log.params == %{item_ids: [4, 5]}
    end

    test "posts.delete_all with empty params" do
      context = AuditLog.system()
      log = AuditLog.build!(context, "posts.delete_all", %{})

      assert log.action == "posts.delete_all"
      assert log.params == %{}
    end

    test "accounts.roles_updated with user_id, roles, before_roles, source" do
      context = AuditLog.system()

      log =
        AuditLog.build!(context, "accounts.roles_updated", %{
          user_id: 1,
          roles: [:system_admin, :member],
          before_roles: [:member],
          source: "admin_ui"
        })

      assert log.action == "accounts.roles_updated"

      assert log.params == %{
               user_id: 1,
               roles: [:system_admin, :member],
               before_roles: [:member],
               source: "admin_ui"
             }
    end
  end

  describe "build!/3 with invalid params" do
    test "raises InvalidParameterError for extra keys" do
      context = AuditLog.system()

      assert_raise AuditLog.InvalidParameterError, ~r/extra keys/, fn ->
        AuditLog.build!(context, "posts.create", %{item_id: 1, extra: "nope"})
      end
    end

    test "raises InvalidParameterError for missing required keys" do
      context = AuditLog.system()

      assert_raise AuditLog.InvalidParameterError, ~r/missing keys/, fn ->
        AuditLog.build!(context, "accounts.login", %{})
      end
    end

    test "raises for extra keys on delete_all" do
      context = AuditLog.system()

      assert_raise AuditLog.InvalidParameterError, ~r/extra keys/, fn ->
        AuditLog.build!(context, "posts.delete_all", %{foo: "bar"})
      end
    end

    test "raises InvalidParameterError for roles_updated with extra keys" do
      context = AuditLog.system()

      assert_raise AuditLog.InvalidParameterError, ~r/extra keys/, fn ->
        AuditLog.build!(context, "accounts.roles_updated", %{
          user_id: 1,
          roles: [:member],
          before_roles: [],
          source: "test",
          extra_key: "nope"
        })
      end
    end

    test "raises InvalidParameterError for roles_updated with missing keys" do
      context = AuditLog.system()

      assert_raise AuditLog.InvalidParameterError, ~r/missing keys/, fn ->
        AuditLog.build!(context, "accounts.roles_updated", %{
          user_id: 1
        })
      end
    end
  end

  describe "Repo.insert!/1 round-trip" do
    test "inserts and retrieves with Blank.Types.IP" do
      log = AuditLog.system()
      log = %{log | action: "app.test", ip_address: {192, 168, 1, 1}}
      inserted = Repo.insert!(log)

      assert inserted.id
      assert inserted.action == "app.test"
      assert inserted.ip_address == {192, 168, 1, 1}
      assert inserted.user_agent == "SYSTEM"
    end
  end

  describe "actor and extra fields" do
    test "actor fields default to nil" do
      log = %AuditLog{action: "test.create"}
      assert log.actor_display_name == nil
      assert log.actor_email == nil
    end

    test "extra field defaults to empty map" do
      log = %AuditLog{action: "test.create"}
      assert log.extra == %{}
    end

    test "system/0 sets extra to empty map" do
      system = AuditLog.system()
      assert system.extra == %{}
      assert system.actor_display_name == nil
      assert system.actor_email == nil
    end

    test "build!/3 preserves extra in audit context params" do
      context = %AuditLog{
        action: "context",
        params: %{},
        extra: %{caller_key: "value"},
        actor_display_name: "Jane Doe",
        actor_email: "jane@example.com"
      }

      log = AuditLog.build!(context, "app.custom", %{foo: "bar"})
      # build!/3 merges audit_context.params into the new log's params
      # extra and actor fields are NOT automatically merged by build!/3
      # (they stay as schema defaults on the new struct)
      assert log.action == "app.custom"
      assert log.params == %{foo: "bar"}
    end

    test "build!/3 accepts extra as action param" do
      context = %AuditLog{action: "context", params: %{}}
      log = AuditLog.build!(context, "app.custom", %{extra: %{note: "test"}})
      # build!/3 merges the action params into the new log's params
      # extra is a schema field, NOT in params — so it stays at default
      assert log.action == "app.custom"
      assert log.params == %{extra: %{note: "test"}}
    end
  end

  describe "belongs_to :user" do
    test "inserts audit log with associated user" do
      user = Repo.insert!(%Blank.Accounts.User{email: "test@example.com", name: "Test User"})

      log = AuditLog.system()
      log = %{log | action: "app.test", user_id: user.id}
      inserted = Repo.insert!(log)

      assert inserted.user_id == user.id
    end
  end
end
