defmodule Blank.ScopeTest do
  use ExUnit.Case, async: true

  alias Blank.Scope

  describe "struct creation" do
    test "creates a scope with required :resource_type" do
      scope = %Scope{resource_type: :user}
      assert scope.resource_type == :user
    end

    test "raises when :resource_type is missing" do
      assert_raise ArgumentError, fn ->
        struct!(Scope, %{})
      end
    end

    test "default resource_id is nil" do
      scope = %Scope{resource_type: :user}
      assert scope.resource_id == nil
    end

    test "default extra is empty map" do
      scope = %Scope{resource_type: :user}
      assert scope.extra == %{}
    end

    test "can set all fields" do
      scope = %Scope{
        resource_type: :post,
        resource_id: 42,
        extra: %{tenant: "acme"}
      }

      assert scope.resource_type == :post
      assert scope.resource_id == 42
      assert scope.extra == %{tenant: "acme"}
    end
  end

  describe "typespec" do
    test "is a valid struct" do
      assert %Scope{resource_type: :anything} |> is_struct(Scope)
    end
  end
end
