defmodule Blank.Authorization.PolicyTest do
  use ExUnit.Case, async: true

  # A consumer policy module that uses the behaviour but does NOT override policy/3
  defmodule NoOverridePolicy do
    use Blank.Authorization.Policy
  end

  # A consumer policy module that overrides policy/3 completely
  defmodule CustomPolicy do
    use Blank.Authorization.Policy

    @impl true
    def policy(%{roles: roles}, _action, %{resource_type: resource_type}) do
      :member in roles and resource_type == :post
    end
  end

  # A consumer policy module that overrides one clause and delegates the rest via super
  defmodule PartialOverridePolicy do
    use Blank.Authorization.Policy

    @impl true
    def policy(_user, :read, _scope), do: true
    def policy(user, action, scope), do: super(user, action, scope)
  end

  describe "use Blank.Authorization.Policy" do
    test "declares @behaviour Blank.Authorization.Policy" do
      # function_exported? checks public functions — policy/3 is injected by use
      assert function_exported?(NoOverridePolicy, :policy, 3)
    end

    test "injects default policy/3 that returns false" do
      user = %{roles: [:member]}
      scope = %{resource_type: :user}

      assert NoOverridePolicy.policy(user, :create, scope) == false
    end

    test "consumer can override policy/3" do
      member_on_post = %{roles: [:member]}
      member_on_user = %{roles: [:member]}
      admin_on_post = %{roles: [:system_admin]}
      scope_post = %{resource_type: :post}
      scope_user = %{resource_type: :user}

      # CustomPolicy allows member on post, denies everything else
      assert CustomPolicy.policy(member_on_post, :create, scope_post) == true
      assert CustomPolicy.policy(member_on_user, :create, scope_user) == false
      assert CustomPolicy.policy(admin_on_post, :create, scope_post) == false
    end

    test "partial override with super: unoverridden clauses delegate to default false" do
      user = %{roles: [:member]}
      scope = %{resource_type: :user}

      # :read is overridden to true
      assert PartialOverridePolicy.policy(user, :read, scope) == true

      # :create delegates to super -> default false
      assert PartialOverridePolicy.policy(user, :create, scope) == false
      assert PartialOverridePolicy.policy(user, :update, scope) == false
      assert PartialOverridePolicy.policy(user, :delete, scope) == false
    end
  end
end
