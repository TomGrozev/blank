defmodule Blank.Authorization.DefaultPolicy do
  @moduledoc """
  Default policy — closed by default. Returns `false` for all inputs.

  The `:system_admin` break-glass is handled by `Blank.Authorization.can?/3`,
  not here. Consumer policies never see `:system_admin` cases because the
  wrapper short-circuits before dispatching.
  """

  @doc false
  @spec policy(term(), term(), term()) :: false
  def policy(_user, _action, _scope), do: false
end
