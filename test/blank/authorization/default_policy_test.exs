defmodule Blank.Authorization.DefaultPolicyTest do
  use ExUnit.Case, async: true

  alias Blank.Authorization.DefaultPolicy

  describe "policy/3" do
    test "returns false for any user/action/scope" do
      user = %{roles: [:member]}
      scope = %{resource_type: :user}

      assert DefaultPolicy.policy(user, :create, scope) == false
      assert DefaultPolicy.policy(user, :read, scope) == false
      assert DefaultPolicy.policy(user, :update, scope) == false
      assert DefaultPolicy.policy(user, :delete, scope) == false
    end

    test "returns false for system_admin (break-glass is wrapper's job)" do
      user = %{roles: [:system_admin]}
      scope = %{resource_type: :user}

      # DefaultPolicy itself does NOT do the system_admin check —
      # that is the responsibility of Blank.Authorization.can?/3
      assert DefaultPolicy.policy(user, :create, scope) == false
    end

    test "returns false for member" do
      user = %{roles: [:member]}
      scope = %{resource_type: :post}

      assert DefaultPolicy.policy(user, :create, scope) == false
    end

    test "returns false for nil user" do
      scope = %{resource_type: :user}

      assert DefaultPolicy.policy(nil, :create, scope) == false
    end
  end
end
