defmodule Blank.Utils.OptsValidatorsTest do
  use ExUnit.Case, async: true

  alias Blank.Utils.OptsValidators

  test "accepts remote function capture with matching arity" do
    ast = quote(do: &Mod.func/1)
    assert {:ok, ^ast} = OptsValidators.validate_fun_ast(ast, 1)
  end

  test "accepts remote function capture with arity 2" do
    ast = quote(do: &Mod.func/2)
    assert {:ok, ^ast} = OptsValidators.validate_fun_ast(ast, 2)
  end

  test "rejects remote function capture with wrong arity" do
    ast = quote(do: &Mod.func/2)
    # Note: clause 2 has a pattern that doesn't match &Mod.func/N ASTs,
    # so wrong arity falls through to the catch-all clause.
    assert {:error, "invalid function passed"} =
             OptsValidators.validate_fun_ast(ast, 1)
  end

  test "rejects non-function" do
    ast = quote(do: 42)

    assert {:error, "invalid function passed"} =
             OptsValidators.validate_fun_ast(ast, 1)
  end

  test "rejects local function capture" do
    ast = quote(do: &func/1)

    assert {:error, "invalid function passed"} =
             OptsValidators.validate_fun_ast(ast, 1)
  end

  test "rejects remote function capture with arity 0 when expecting 2" do
    ast = quote(do: &Mod.func/0)

    assert {:error, "invalid function passed"} =
             OptsValidators.validate_fun_ast(ast, 2)
  end
end
