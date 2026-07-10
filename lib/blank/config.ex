defmodule Blank.Config do
  @moduledoc """
  Configuration management for Blank.

  Handles caching of configuration values that are computed at boot time.
  """

  @allowed_roles_key {Blank.Authorization, :allowed_roles}

  @doc """
  Returns the cached allowed roles set.

  If not cached (e.g., called before boot), computes and caches it.
  """
  @spec allowed_roles() :: MapSet.t(atom())
  def allowed_roles do
    case :persistent_term.get(@allowed_roles_key, :not_set) do
      :not_set -> compute_and_cache_allowed_roles()
      roles -> roles
    end
  end

  @doc """
  Computes the allowed roles from config and caches them.
  Called at app boot time.
  """
  @spec compute_and_cache_allowed_roles() :: MapSet.t(atom())
  def compute_and_cache_allowed_roles do
    built_in = MapSet.new([:system_admin, :member])

    configured =
      :blank
      |> Application.get_env(:authorization, [])
      |> Keyword.get(:roles, [])

    roles = MapSet.union(built_in, MapSet.new(configured))
    :persistent_term.put(@allowed_roles_key, roles)
    roles
  end
end
