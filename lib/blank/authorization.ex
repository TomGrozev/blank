defmodule Blank.Authorization do
  @moduledoc """
  Authorization utilities for Blank.

  Provides role validation and the allowed-roles set used by `Blank.Types.Role`
  and other authorization-aware code paths.
  """

  @built_in_roles MapSet.new([:system_admin, :member])
  @allowed_roles_key {__MODULE__, :allowed_roles}

  @doc """
  Returns the full set of allowed role atoms.

  The allowed-set is the union of the built-in roles (`:system_admin`, `:member`)
  and any consumer-configured roles from `config :blank, :authorization, roles: [...]`.

  The set is computed once at app boot and cached for the lifetime of the application.
  """
  @spec allowed_roles() :: MapSet.t(atom())
  def allowed_roles do
    # Read from persistent term cache (set at boot)
    case :persistent_term.get(@allowed_roles_key, :not_set) do
      :not_set ->
        # Fallback for when called before boot (e.g., in tests before app start)
        compute_and_cache_allowed_roles()

      roles ->
        roles
    end
  end

  @doc """
  Computes the allowed roles from config and caches them.
  Called at app boot time.
  """
  @spec compute_and_cache_allowed_roles() :: MapSet.t(atom())
  def compute_and_cache_allowed_roles do
    configured =
      :blank
      |> Application.get_env(:authorization, [])
      |> Keyword.get(:roles, [])

    roles = MapSet.union(@built_in_roles, MapSet.new(configured))
    :persistent_term.put(@allowed_roles_key, roles)
    roles
  end

  @doc """
  Validates that all roles in the given list are in the allowed-set.

  Returns `:ok` if all roles are allowed, or `{:error, invalid_roles}` with the
  list of disallowed atoms.

  ## Examples

      iex> validate_roles([:system_admin, :member])
      :ok

      iex> validate_roles([:system_admin, :unknown_role])
      {:error, [:unknown_role]}
  """
  @spec validate_roles([atom()]) :: :ok | {:error, [atom()]}
  def validate_roles(roles) when is_list(roles) do
    allowed = allowed_roles()

    invalid =
      roles
      |> Enum.reject(&MapSet.member?(allowed, &1))
      |> Enum.uniq()

    case invalid do
      [] -> :ok
      invalid -> {:error, invalid}
    end
  end

  @doc """
  Returns the built-in roles that are always present regardless of config.
  """
  @spec built_in_roles() :: MapSet.t(atom())
  def built_in_roles, do: @built_in_roles
end
