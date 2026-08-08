defmodule Blank.Authorization.RoleMappers.OIDCCTest do
  use ExUnit.Case, async: true

  alias Blank.Authorization.RoleMappers.OIDCC

  # ── Helpers ──

  defp auth_with_groups(groups) do
    %Ueberauth.Auth{
      provider: :oidcc,
      uid: "sub-12345",
      info: %Ueberauth.Auth.Info{email: "user@example.com", name: "OIDC User"},
      extra: %Ueberauth.Auth.Extra{raw_info: %{"groups" => groups}}
    }
  end

  defp auth_without_groups do
    %Ueberauth.Auth{
      provider: :oidcc,
      uid: "sub-12345",
      info: %Ueberauth.Auth.Info{email: "user@example.com", name: "OIDC User"},
      extra: %Ueberauth.Auth.Extra{raw_info: %{}}
    }
  end

  @groups_to_roles %{
    "admin" => :system_admin,
    "payments" => :payment_manager
  }

  # ── Behaviour compliance ──

  describe "behaviour compliance" do
    test "implements Blank.Authorization.RoleMapper behaviour" do
      attrs = OIDCC.__info__(:attributes)
      behaviours = Keyword.get_values(attrs, :behaviour) |> List.flatten()
      assert Blank.Authorization.RoleMapper in behaviours
    end
  end

  # ── Basic mapping ──

  describe "map_claims/2 with matching groups" do
    test "maps a single matching group to its role atom" do
      auth = auth_with_groups(["admin"])
      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == [:system_admin]
    end

    test "maps multiple matching groups to their role atoms" do
      auth = auth_with_groups(["admin", "payments"])
      opts = [groups_to_roles: @groups_to_roles]

      roles = OIDCC.map_claims(auth, opts)
      assert :system_admin in roles
      assert :payment_manager in roles
      assert length(roles) == 2
    end
  end

  # ── No matches ──

  describe "map_claims/2 with no matching groups" do
    test "returns empty list when no groups match the config" do
      auth = auth_with_groups(["unrelated-group"])
      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == []
    end

    test "returns empty list when auth has no groups claim" do
      auth = auth_without_groups()
      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == []
    end

    test "returns empty list when groups list is empty" do
      auth = auth_with_groups([])
      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == []
    end
  end

  # ── De-duplication ──

  describe "map_claims/2 de-duplication" do
    test "returns each role only once even if user is in multiple groups mapping to the same role" do
      opts = [groups_to_roles: %{"group-a" => :member, "group-b" => :member}]
      auth = auth_with_groups(["group-a", "group-b"])

      roles = OIDCC.map_claims(auth, opts)
      assert roles == [:member]
    end

    test "returns each role once when user appears in the same group multiple times" do
      auth = auth_with_groups(["admin", "admin"])
      opts = [groups_to_roles: @groups_to_roles]

      roles = OIDCC.map_claims(auth, opts)
      assert roles == [:system_admin]
    end
  end

  # ── Missing opts ──

  describe "map_claims/2 with missing opts" do
    test "returns empty list when groups_to_roles opt is not provided" do
      auth = auth_with_groups(["admin"])

      assert OIDCC.map_claims(auth, []) == []
    end

    test "returns empty list when groups_to_roles is nil" do
      auth = auth_with_groups(["admin"])
      opts = [groups_to_roles: nil]

      assert OIDCC.map_claims(auth, opts) == []
    end
  end

  # ── Integration: ueberauth callback path ──

  describe "integration with ueberauth callback path" do
    test "an OIDCC user with groups: [\"admin\"] ends up with :system_admin after login" do
      auth = auth_with_groups(["admin"])
      opts = [groups_to_roles: @groups_to_roles]

      raw_roles = OIDCC.map_claims(auth, opts)
      roles = if raw_roles == [], do: [:member], else: raw_roles

      assert roles == [:system_admin]
      assert :system_admin in roles
    end
  end

  # ── Edge cases: malformed auth ──

  describe "map_claims/2 with malformed auth" do
    test "returns empty list when raw_info is not a map" do
      auth = %Ueberauth.Auth{
        provider: :oidcc,
        uid: "sub-12345",
        info: %Ueberauth.Auth.Info{email: "user@example.com", name: "OIDC User"},
        extra: %Ueberauth.Auth.Extra{raw_info: "not-a-map"}
      }

      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == []
    end

    test "returns empty list when extra is nil" do
      auth = %Ueberauth.Auth{
        provider: :oidcc,
        uid: "sub-12345",
        info: %Ueberauth.Auth.Info{email: "user@example.com", name: "OIDC User"},
        extra: nil
      }

      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == []
    end

    test "returns empty list when groups value is not a list" do
      auth = %Ueberauth.Auth{
        provider: :oidcc,
        uid: "sub-12345",
        info: %Ueberauth.Auth.Info{email: "user@example.com", name: "OIDC User"},
        extra: %Ueberauth.Auth.Extra{raw_info: %{"groups" => "not-a-list"}}
      }

      opts = [groups_to_roles: @groups_to_roles]

      assert OIDCC.map_claims(auth, opts) == []
    end

    test "returns empty list when groups_to_roles is not a map" do
      auth = auth_with_groups(["admin"])
      opts = [groups_to_roles: "not-a-map"]

      assert OIDCC.map_claims(auth, opts) == []
    end
  end
end
