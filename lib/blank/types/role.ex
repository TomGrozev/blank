defmodule Blank.Types.Role do
  @moduledoc """
  Custom Ecto type for role atoms.

  Stores roles as strings in the database and casts them to/from atoms in memory.
  Only roles in the configured allowed-set (see `Blank.Authorization.allowed_roles/0`)
  are accepted during cast. Built-in roles `:system_admin` and `:member` are always
  allowed.

  Strings are converted via `String.to_existing_atom/1` to prevent atom exhaustion.
  """

  use Ecto.Type

  @doc """
  The underlying database type.
  """
  def type, do: :string

  @doc """
  Casts a value to a role atom.

  Accepts atoms (validated against the allowed-set) or strings (converted via
  `String.to_existing_atom/1` then validated). Returns `:error` for anything
  outside the allowed-set or for strings that don't correspond to existing atoms.
  """
  def cast(value) when is_atom(value) do
    if MapSet.member?(Blank.Authorization.allowed_roles(), value) do
      {:ok, value}
    else
      :error
    end
  end

  def cast(value) when is_binary(value) do
    try do
      atom = String.to_existing_atom(value)
      cast(atom)
    rescue
      ArgumentError -> :error
    end
  end

  def cast(_), do: :error

  @doc """
  Loads a role string from the database and converts to an atom.
  """
  def load(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  end

  @doc """
  Dumps a role atom to a string for database storage.
  """
  def dump(value) when is_atom(value) do
    {:ok, Atom.to_string(value)}
  end

  def dump(_), do: :error

  @doc """
  Uses itself in an embed.
  """
  def embed_as(_), do: :self

  @doc """
  Checks if two role atoms are equal.
  """
  def equal?(role1, role2), do: role1 == role2
end
