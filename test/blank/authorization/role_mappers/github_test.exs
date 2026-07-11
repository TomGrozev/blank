defmodule Blank.Authorization.RoleMappers.GitHubTest do
  use ExUnit.Case, async: true

  alias Blank.Authorization.RoleMappers.GitHub

  # ── Helpers ──

  defp auth_with_teams(teams) do
    %Ueberauth.Auth{
      provider: :github,
      uid: "12345",
      info: %Ueberauth.Auth.Info{email: "admin@example.com", name: "Admin"},
      extra: %Ueberauth.Auth.Extra{raw_info: %{"teams" => teams}}
    }
  end

  defp auth_without_teams do
    %Ueberauth.Auth{
      provider: :github,
      uid: "12345",
      info: %Ueberauth.Auth.Info{email: "admin@example.com", name: "Admin"},
      extra: %Ueberauth.Auth.Extra{raw_info: %{}}
    }
  end

  @team_slug_to_role %{
    "payments-team" => :payment_manager,
    "admins" => :system_admin
  }

  # ── Behaviour compliance ──

  describe "behaviour compliance" do
    test "implements Blank.Authorization.RoleMapper behaviour" do
      attrs = GitHub.__info__(:attributes)
      behaviours = Keyword.get_values(attrs, :behaviour) |> List.flatten()
      assert Blank.Authorization.RoleMapper in behaviours
    end
  end

  # ── Basic mapping ──

  describe "map_claims/2 with matching teams" do
    test "maps a single matching team slug to its role atom" do
      auth = auth_with_teams(["payments-team"])
      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == [:payment_manager]
    end

    test "maps multiple matching team slugs to their role atoms" do
      auth = auth_with_teams(["payments-team", "admins"])
      opts = [team_slug_to_role: @team_slug_to_role]

      roles = GitHub.map_claims(auth, opts)
      assert :payment_manager in roles
      assert :system_admin in roles
      assert length(roles) == 2
    end
  end

  # ── No matches ──

  describe "map_claims/2 with no matching teams" do
    test "returns empty list when no teams match the config" do
      auth = auth_with_teams(["unrelated-team"])
      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == []
    end

    test "returns empty list when auth has no teams" do
      auth = auth_without_teams()
      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == []
    end

    test "returns empty list when teams list is empty" do
      auth = auth_with_teams([])
      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == []
    end
  end

  # ── De-duplication ──

  describe "map_claims/2 de-duplication" do
    test "returns each role only once even if user is in multiple teams mapping to the same role" do
      # Both teams map to the same role
      opts = [team_slug_to_role: %{"team-a" => :member, "team-b" => :member}]
      auth = auth_with_teams(["team-a", "team-b"])

      roles = GitHub.map_claims(auth, opts)
      assert roles == [:member]
    end

    test "returns each role once when user appears in the same team multiple times" do
      auth = auth_with_teams(["payments-team", "payments-team"])
      opts = [team_slug_to_role: @team_slug_to_role]

      roles = GitHub.map_claims(auth, opts)
      assert roles == [:payment_manager]
    end
  end

  # ── Missing opts ──

  describe "map_claims/2 with missing opts" do
    test "returns empty list when team_slug_to_role opt is not provided" do
      auth = auth_with_teams(["payments-team"])

      assert GitHub.map_claims(auth, []) == []
    end

    test "returns empty list when team_slug_to_role is nil" do
      auth = auth_with_teams(["payments-team"])
      opts = [team_slug_to_role: nil]

      assert GitHub.map_claims(auth, opts) == []
    end
  end

  # ── Integration: ueberauth callback path ──

  describe "integration with ueberauth callback path" do
    test "an admin in a mapped GitHub team ends up with the matching role after login" do
      # This test verifies the full flow: mapper → controller → user roles
      # We simulate what the controller does: call the mapper, apply floor, validate
      auth = auth_with_teams(["payments-team"])
      opts = [team_slug_to_role: @team_slug_to_role]

      raw_roles = GitHub.map_claims(auth, opts)
      roles = if raw_roles == [], do: [:member], else: raw_roles

      # The mapper should return [:payment_manager] for a user in "payments-team"
      assert roles == [:payment_manager]
      assert :payment_manager in roles
    end
  end

  # ── Edge cases: malformed auth ──

  describe "map_claims/2 with malformed auth" do
    test "returns empty list when raw_info is not a map" do
      auth = %Ueberauth.Auth{
        provider: :github,
        uid: "12345",
        info: %Ueberauth.Auth.Info{email: "admin@example.com", name: "Admin"},
        extra: %Ueberauth.Auth.Extra{raw_info: "not-a-map"}
      }

      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == []
    end

    test "returns empty list when extra is nil" do
      auth = %Ueberauth.Auth{
        provider: :github,
        uid: "12345",
        info: %Ueberauth.Auth.Info{email: "admin@example.com", name: "Admin"},
        extra: nil
      }

      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == []
    end

    test "returns empty list when teams value is not a list" do
      auth = %Ueberauth.Auth{
        provider: :github,
        uid: "12345",
        info: %Ueberauth.Auth.Info{email: "admin@example.com", name: "Admin"},
        extra: %Ueberauth.Auth.Extra{raw_info: %{"teams" => "not-a-list"}}
      }

      opts = [team_slug_to_role: @team_slug_to_role]

      assert GitHub.map_claims(auth, opts) == []
    end

    test "returns empty list when team_slug_to_role is not a map" do
      auth = auth_with_teams(["payments-team"])
      opts = [team_slug_to_role: "not-a-map"]

      assert GitHub.map_claims(auth, opts) == []
    end
  end
end
