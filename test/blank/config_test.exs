defmodule Blank.ConfigTest do
  # Not async: mutates :persistent_term global state
  use ExUnit.Case

  alias Blank.Config

  @persistent_term_key {Blank.Authorization, :allowed_roles}

  setup do
    # Save the current persistent_term value (if any) so we can restore it
    saved =
      try do
        :persistent_term.get(@persistent_term_key)
      catch
        :error, :badarg -> :not_set
      end

    on_exit(fn ->
      case saved do
        :not_set -> :persistent_term.erase(@persistent_term_key)
        value -> :persistent_term.put(@persistent_term_key, value)
      end
    end)

    :ok
  end

  describe "allowed_roles/0" do
    test "returns a MapSet" do
      assert %MapSet{} = Config.allowed_roles()
    end

    test "includes built-in roles" do
      allowed = Config.allowed_roles()
      assert MapSet.member?(allowed, :system_admin)
      assert MapSet.member?(allowed, :member)
    end

    test "includes configured roles" do
      # Test config has authorization: [roles: [:content_editor]]
      allowed = Config.allowed_roles()
      assert MapSet.member?(allowed, :content_editor)
    end

    test "returns same result on multiple calls (caching)" do
      roles1 = Config.allowed_roles()
      roles2 = Config.allowed_roles()
      assert roles1 === roles2
    end

    test "falls back to computing when persistent_term is not set" do
      :persistent_term.erase(@persistent_term_key)
      allowed = Config.allowed_roles()
      assert %MapSet{} = allowed
      assert MapSet.member?(allowed, :system_admin)
      assert MapSet.member?(allowed, :member)
    end
  end

  describe "compute_and_cache_allowed_roles/0" do
    test "returns a MapSet" do
      assert %MapSet{} = Config.compute_and_cache_allowed_roles()
    end

    test "includes built-in + configured roles" do
      roles = Config.compute_and_cache_allowed_roles()
      assert MapSet.member?(roles, :system_admin)
      assert MapSet.member?(roles, :member)
      assert MapSet.member?(roles, :content_editor)
    end

    test "is idempotent" do
      roles1 = Config.compute_and_cache_allowed_roles()
      roles2 = Config.compute_and_cache_allowed_roles()
      assert MapSet.equal?(roles1, roles2)
    end

    test "reflects config changes" do
      original_config = Application.get_env(:blank, :authorization)

      try do
        Application.put_env(:blank, :authorization, roles: [:new_role])
        roles = Config.compute_and_cache_allowed_roles()
        assert MapSet.member?(roles, :new_role)
        assert MapSet.member?(roles, :system_admin)
        assert MapSet.member?(roles, :member)
      after
        Application.put_env(:blank, :authorization, original_config)
      end
    end

    test "caches result in persistent_term" do
      Config.compute_and_cache_allowed_roles()
      cached = :persistent_term.get(@persistent_term_key)
      assert %MapSet{} = cached
      assert MapSet.member?(cached, :system_admin)
    end
  end
end
