defmodule Blank.Errors.InvalidConfigErrorTest do
  use ExUnit.Case, async: true

  alias Blank.Errors.InvalidConfigError
  alias Blank.Schema

  test "message/1 includes module name and message" do
    err =
      InvalidConfigError.exception(
        caller: __MODULE__,
        module: Schema,
        usage: "@derive",
        key: :my_key,
        message: "my message"
      )

    msg = Exception.message(err)
    assert msg =~ "Blank.Schema"
    assert msg =~ "my message"
    assert msg =~ "Blank.Errors.InvalidConfigErrorTest"
  end

  test "module_name strips Elixir prefix from caller" do
    err =
      InvalidConfigError.exception(
        caller: Some.Nested.Module,
        module: Schema,
        usage: "@derive",
        key: :foo,
        message: "bad"
      )

    msg = Exception.message(err)
    assert msg =~ "Some.Nested.Module"
    assert msg =~ "bad"
  end

  test "from_nimble/2 builds from NimbleOptions.ValidationError" do
    nimble_error =
      NimbleOptions.ValidationError.exception(
        key: :bad_key,
        keys_path: [],
        message: "unknown option"
      )

    err =
      InvalidConfigError.from_nimble(nimble_error,
        caller: __MODULE__,
        module: Schema,
        usage: "@derive"
      )

    assert %InvalidConfigError{} = err
    assert err.caller == __MODULE__
    assert err.module == Schema
    assert err.key == :bad_key
    assert err.message =~ "unknown option"
  end

  describe "from_app_env/1" do
    test "returns a struct built from the app-env options" do
      usage = """
      The :roles key must be a list of atoms:

          config :blank, :authorization, roles: [:payment_manager]
      """

      err =
        InvalidConfigError.from_app_env(
          caller: :authorization,
          module: Blank.Authorization,
          key: :roles,
          value: "not_a_list",
          usage: usage
        )

      assert %InvalidConfigError{} = err
      assert err.caller == :authorization
      assert err.module == Blank.Authorization
      assert err.usage == usage
      assert err.key == :roles
      assert err.value == "not_a_list"
      assert err.source == :app_env
    end
  end

  describe "message/1" do
    test "with an atom caller returns the dotted module, config key, usage and value" do
      err =
        InvalidConfigError.from_app_env(
          caller: :authorization,
          module: Blank.Authorization,
          key: :roles,
          value: "not_a_list",
          usage: "The :roles key must be a list of atoms"
        )

      msg = Exception.message(err)
      assert msg =~ "invalid Blank.Authorization configuration"
      assert msg =~ "The `:authorization` config key is invalid."
      assert msg =~ "The :roles key must be a list of atoms"
      assert msg =~ "Got: \"not_a_list\""
    end

    test "returns the dotted module name and the caller label" do
      err =
        InvalidConfigError.from_app_env(
          caller: Ueberauth,
          module: Blank.Ueberauth,
          key: :providers,
          value: [],
          usage: "Blank requires at least one Ueberauth provider"
        )

      msg = Exception.message(err)
      assert msg =~ "invalid Blank.Ueberauth configuration"
      assert msg =~ "The `Ueberauth` config key is invalid."
      assert msg =~ "Blank requires at least one Ueberauth provider"
      assert msg =~ "Got: []"
    end

    test "with a nil config value returns the nil in the Got line" do
      err =
        InvalidConfigError.from_app_env(
          caller: :authorization,
          module: Blank.Authorization,
          key: :roles,
          value: nil,
          usage: "The :roles key must be a list of atoms"
        )

      assert Exception.message(err) =~ "Got: nil"
    end
  end
end
