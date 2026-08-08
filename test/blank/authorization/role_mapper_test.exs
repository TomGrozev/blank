defmodule Blank.Authorization.RoleMapperTest do
  use ExUnit.Case, async: true

  describe "RoleMapper behaviour" do
    test "a module using the behaviour implements map_claims/2" do
      defmodule TestMapper do
        use Blank.Authorization.RoleMapper

        @impl Blank.Authorization.RoleMapper
        def map_claims(_auth, _opts), do: [:member]
      end

      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "123",
        info: %Ueberauth.Auth.Info{email: "test@example.com", name: "Test"}
      }

      assert TestMapper.map_claims(auth, []) == [:member]
    end

    test "the behaviour declares the map_claims/2 callback" do
      behaviours = Blank.Authorization.RoleMapper.behaviour_info(:callbacks)
      assert {:map_claims, 2} in behaviours
    end
  end
end
