defmodule Blank.Utils.OptsValidators do
  @moduledoc false

  @doc """
  Validates a function ref as ast

  Called in nimbleopts by `{:custom, Blank.Utils.OptsValidators,
  :validate_fun_ast, [<airity>]}`, where `<arity>` is the arity to validate.
  """
  def validate_fun_ast({:&, _, [{:/, _, [{{:., _, [_mod, _fun]}, _, _}, arity]}]} = value, arity) do
    {:ok, value}
  end

  def validate_fun_ast({:&, _, [{:/, _, [{:., _, [_, _]}, passed_arity]}]}, arity) do
    {:error, "invalid arity #{passed_arity}, expected arity of #{arity}"}
  end

  def validate_fun_ast(_, _), do: {:error, "invalid function passed"}
end
