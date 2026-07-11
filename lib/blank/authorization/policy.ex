defmodule Blank.Authorization.Policy do
  @moduledoc """
  Behaviour for authorization policies.

  Consumer modules implement `policy/3` to decide whether a user can perform
  an action on a scope. The `use Blank.Authorization.Policy` macro injects
  a default `policy/3` fallback that returns `false`, marked as `defoverridable`.
  """

  @doc """
  Callback to decide whether a user may perform an action on a scope.

  Returns `true` to allow, `false` to deny.
  """
  @callback policy(user :: term(), action :: term(), scope :: term()) :: boolean()

  defmacro __using__(_opts) do
    quote do
      @behaviour Blank.Authorization.Policy

      @doc false
      def policy(user, action, scope),
        do: Blank.Authorization.DefaultPolicy.policy(user, action, scope)

      defoverridable policy: 3
    end
  end
end
