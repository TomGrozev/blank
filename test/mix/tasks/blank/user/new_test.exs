defmodule Mix.Tasks.Blank.User.NewTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias Blank.Accounts.User
  alias Blank.Audit.AuditLog

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(TestApp.Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  describe "run/1 creates user with full attributes" do
    test "creates user with email, password, name, and roles" do
      Mix.shell(Mix.Shell.Process)

      Mix.Tasks.Blank.User.New.run([
        "--email",
        "admin@example.com",
        "--password",
        "Password123!",
        "--name",
        "Admin User",
        "--roles",
        "system_admin,member",
        "-r",
        "TestApp.Repo"
      ])

      user = TestApp.Repo.one!(from(u in User, where: u.email == "admin@example.com"))
      assert user.email == "admin@example.com"
      assert user.name == "Admin User"
      assert user.roles == ["system_admin", "member"]
      assert is_nil(user.provider)
      assert is_nil(user.external_uid)

      audit_log =
        TestApp.Repo.one!(
          from(a in AuditLog, where: a.action == "accounts.user_created", limit: 1)
        )

      assert audit_log.action == "accounts.user_created"

      assert audit_log.params == %{
               "email" => "admin@example.com",
               "roles" => ["system_admin", "member"]
             }

      assert audit_log.user_agent == "SYSTEM"
      assert is_nil(audit_log.user_id)
    end
  end

  describe "run/1 creates user without optional attributes" do
    test "creates user without name or roles" do
      Mix.shell(Mix.Shell.Process)

      Mix.Tasks.Blank.User.New.run([
        "--email",
        "basic@example.com",
        "--password",
        "Password123!",
        "-r",
        "TestApp.Repo"
      ])

      user = TestApp.Repo.one!(from(u in User, where: u.email == "basic@example.com"))
      assert user.email == "basic@example.com"
      assert is_nil(user.name)
      assert user.roles == []
      assert is_nil(user.provider)
      assert is_nil(user.external_uid)
    end
  end

  describe "run/1 rejects disallowed flags" do
    test "rejects --provider flag" do
      Mix.shell(Mix.Shell.Process)

      assert_raise OptionParser.ParseError, fn ->
        Mix.Tasks.Blank.User.New.run([
          "--email",
          "test@example.com",
          "--password",
          "Password123!",
          "--provider",
          "github",
          "-r",
          "TestApp.Repo"
        ])
      end
    end

    test "rejects --external_uid flag" do
      Mix.shell(Mix.Shell.Process)

      assert_raise OptionParser.ParseError, fn ->
        Mix.Tasks.Blank.User.New.run([
          "--email",
          "test@example.com",
          "--password",
          "Password123!",
          "--external_uid",
          "12345",
          "-r",
          "TestApp.Repo"
        ])
      end
    end
  end
end
