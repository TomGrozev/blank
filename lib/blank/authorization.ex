defmodule Blank.Authorization do
  @moduledoc """
  Authorization utilities for Blank.

  Provides role validation and the allowed-roles set used by `Blank.Types.Role`
  and other authorization-aware code paths.
  """

  @built_in_roles MapSet.new([:system_admin, :member])

  @doc """
  Returns the full set of allowed role atoms.

  The allowed-set is the union of the built-in roles (`:system_admin`, `:member`)
  and any consumer-configured roles from `config :blank, :authorization, roles: [...]`.

  The set is computed once at app boot and cached for the lifetime of the application.
  """
  @spec allowed_roles() :: MapSet.t(atom())
  def allowed_roles do
    Blank.Config.allowed_roles()
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
      |> Stream.reject(&MapSet.member?(allowed, &1))
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
