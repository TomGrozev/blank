defmodule Blank.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Blank.Authorization

  describe "allowed_roles/0" do
    test "includes built-in roles" do
      allowed = Authorization.allowed_roles()
      assert MapSet.member?(allowed, :system_admin)
      assert MapSet.member?(allowed, :member)
    end

    test "includes configured roles" do
      # Test config has roles: [:content_editor] in test.exs
      allowed = Authorization.allowed_roles()
      assert MapSet.member?(allowed, :content_editor)
    end

    test "returns a MapSet" do
      assert %MapSet{} = Authorization.allowed_roles()
    end
  end

  describe "allowed_roles/0 caching" do
    test "returns the same MapSet on multiple calls" do
      roles1 = Authorization.allowed_roles()
      roles2 = Authorization.allowed_roles()
      assert roles1 === roles2
    end
  end

  describe "built_in_roles/0" do
    test "returns the built-in roles" do
      built_in = Authorization.built_in_roles()
      assert MapSet.equal?(built_in, MapSet.new([:system_admin, :member]))
    end
  end

  describe "validate_roles/1" do
    test "returns :ok for all built-in roles" do
      assert :ok = Authorization.validate_roles([:system_admin])
      assert :ok = Authorization.validate_roles([:member])
      assert :ok = Authorization.validate_roles([:system_admin, :member])
    end

    test "returns :ok for configured roles" do
      assert :ok = Authorization.validate_roles([:content_editor])
    end

    test "returns :ok for empty list" do
      assert :ok = Authorization.validate_roles([])
    end

    test "returns {:error, [...]} for unknown roles" do
      assert {:error, [:nonexistent_role]} = Authorization.validate_roles([:nonexistent_role])
    end

    test "returns all invalid roles in error" do
      assert {:error, invalid} = Authorization.validate_roles([:system_admin, :fake1, :fake2])
      assert :fake1 in invalid
      assert :fake2 in invalid
      refute :system_admin in invalid
    end

    test "deduplicates invalid roles" do
      assert {:error, [:fake_role]} = Authorization.validate_roles([:fake_role, :fake_role])
    end
  end
end
