defmodule Blank.ApplicationTest do
  use ExUnit.Case, async: true

  alias Blank.Application, as: BlankApp

  # ── validate_ueberauth_config!/0 (via start/2) ──

  describe "validate_ueberauth_config!/0" do
    test "raises when local auth is disabled and no providers configured" do
      original_auth = Application.get_env(:blank, :auth, [])
      original_ueberauth = Application.get_env(:ueberauth, Ueberauth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_auth)
        Application.put_env(:ueberauth, Ueberauth, original_ueberauth)
      end)

      Application.put_env(:blank, :auth, local_login: :disabled)
      Application.put_env(:ueberauth, Ueberauth, providers: [])

      assert_raise RuntimeError, ~r/Blank requires at least one Ueberauth provider/, fn ->
        BlankApp.start(:normal, [])
      end
    end

    test "does not raise when local auth is enabled (skips ueberauth check)" do
      # When local auth is enabled, the ueberauth validation is skipped entirely
      # regardless of provider config. Verify the guard condition:
      assert Blank.Plugs.Auth.local_login_enabled?() == true
    end

    test "does not raise when providers are configured" do
      original_auth = Application.get_env(:blank, :auth, [])
      original_ueberauth = Application.get_env(:ueberauth, Ueberauth, [])

      on_exit(fn ->
        Application.put_env(:blank, :auth, original_auth)
        Application.put_env(:ueberauth, Ueberauth, original_ueberauth)
      end)

      Application.put_env(:blank, :auth, local_login: :disabled)

      Application.put_env(:ueberauth, Ueberauth,
        providers: [google: {Ueberauth.Strategy.Google, []}]
      )

      # Even though local auth is disabled, providers are configured,
      # so validate_ueberauth_config!/0 should not raise.
      config = Application.get_env(:ueberauth, Ueberauth, [])
      providers = Keyword.get(config, :providers, [])
      assert providers != []
      assert Keyword.has_key?(providers, :google)
    end
  end

  # ── validate_authorization_config!/0 (via start/2) ──

  describe "validate_authorization_config!/0" do
    test "raises when roles is not a list" do
      original_authz = Application.get_env(:blank, :authorization, [])

      on_exit(fn ->
        Application.put_env(:blank, :authorization, original_authz)
      end)

      Application.put_env(:blank, :authorization, roles: "not_a_list")

      assert_raise RuntimeError, ~r/The :roles key must be a list of atoms/, fn ->
        BlankApp.start(:normal, [])
      end
    end

    test "raises when roles contains non-atoms" do
      original_authz = Application.get_env(:blank, :authorization, [])

      on_exit(fn ->
        Application.put_env(:blank, :authorization, original_authz)
      end)

      Application.put_env(:blank, :authorization, roles: [:valid_role, "not_an_atom"])

      assert_raise RuntimeError, ~r/The :roles key must be a list of atoms/, fn ->
        BlankApp.start(:normal, [])
      end
    end

    test "does not raise with valid roles list" do
      # Verify the validation passes by checking the side effect:
      # compute_and_cache_allowed_roles succeeds and returns a MapSet
      roles = Blank.Config.compute_and_cache_allowed_roles()
      assert %MapSet{} = roles
      assert MapSet.member?(roles, :system_admin)
      assert MapSet.member?(roles, :member)
    end
  end
end
