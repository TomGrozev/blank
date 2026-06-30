defmodule Blank.Errors.InvalidConfigErrorTest do
  use ExUnit.Case, async: true

  test "message/1 includes module name and message" do
    err =
      Blank.Errors.InvalidConfigError.exception(
        caller: __MODULE__,
        module: Blank.Schema,
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
      Blank.Errors.InvalidConfigError.exception(
        caller: Some.Nested.Module,
        module: Blank.Schema,
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
      Blank.Errors.InvalidConfigError.from_nimble(nimble_error,
        caller: __MODULE__,
        module: Blank.Schema,
        usage: "@derive"
      )

    assert %Blank.Errors.InvalidConfigError{} = err
    assert err.caller == __MODULE__
    assert err.module == Blank.Schema
    assert err.key == :bad_key
    assert err.message =~ "unknown option"
  end
end
