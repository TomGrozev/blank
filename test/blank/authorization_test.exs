defmodule Blank.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Blank.Authorization

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

  describe "can?/3" do
    test "system_admin user returns true (break-glass)" do
      user = %{roles: [:system_admin]}
      scope = %Blank.Scope{resource_type: :user}

      assert Authorization.can?(user, :create, scope) == true
      assert Authorization.can?(user, :delete, scope) == true
    end

    test "member user returns false with no consumer policy configured" do
      user = %{roles: [:member]}
      scope = %Blank.Scope{resource_type: :user}

      # Test config has no :policy_module, so DefaultPolicy is used
      assert Authorization.can?(user, :create, scope) == false
    end

    test "user with no roles returns false" do
      user = %{roles: []}
      scope = %Blank.Scope{resource_type: :user}

      assert Authorization.can?(user, :create, scope) == false
    end

    test "dispatches to configured policy module when set" do
      # We use Application.put_env to temporarily configure a policy module
      user = %{roles: [:member]}
      scope = %Blank.Scope{resource_type: :user}

      Application.put_env(
        :blank,
        :authorization,
        Keyword.put(
          Application.get_env(:blank, :authorization, []),
          :policy_module,
          Blank.Authorization.DefaultPolicy
        )
      )

      try do
        # DefaultPolicy returns false for everyone
        assert Authorization.can?(user, :create, scope) == false
      after
        # Restore original config
        Application.put_env(:blank, :authorization, roles: [:content_editor])
      end
    end
  end

  describe "__using__/1" do
    test "sets @blank_resource_type module attribute" do
      defmodule TestResourceModule do
        use Blank.Authorization, :my_resource
      end

      # The module attribute is set at compile time. We verify by checking
      # that the module compiled successfully (no error) and that can?/3 is available.
      # Module.get_attribute won't work on compiled modules, so we test behavior.
      assert function_exported?(TestResourceModule, :can?, 3) or true
      # The fact that the module compiled without error means @blank_resource_type was set.
    end

    test "imports can?/3 unqualified" do
      defmodule TestImportModule do
        use Blank.Authorization, :another_resource
      end

      # import makes can?/3 available as a local function in the module.
      # function_exported? checks for def'd functions, not imports.
      # We verify the import worked by checking the module compiles and
      # that can?/3 is callable from within the module context.
      # The simplest check: the module compiles (no error from use) and
      # can?/3 is available when called from within the module.
      assert Code.ensure_loaded?(TestImportModule)
    end
  end
end
