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

  @doc """
  Returns the configured policy module, or `Blank.Authorization.DefaultPolicy`
  if none is configured.

  Reads from `config :blank, :authorization, policy_module: MyApp.Policy`.
  """
  @spec policy_module() :: module()
  def policy_module do
    :blank
    |> Application.get_env(:authorization, [])
    |> Keyword.get(:policy_module, Blank.Authorization.DefaultPolicy)
  end

  @doc """
  Checks whether a user can perform an action on a scope.

  Short-circuits to `true` if the user has the `:system_admin` role (break-glass).
  Otherwise dispatches to the configured policy module's `policy/3` callback.

  ## Examples

      iex> user = %Blank.Accounts.User{roles: [:system_admin]}
      iex> Blank.Authorization.can?(user, :create, %Blank.Scope{resource_type: :user})
      true

      iex> user = %Blank.Accounts.User{roles: [:member]}
      iex> Blank.Authorization.can?(user, :create, %Blank.Scope{resource_type: :user})
      false
  """
  @spec can?(term(), term(), term()) :: boolean()
  def can?(user, action, scope) do
    if :system_admin in List.wrap(user.roles) do
      true
    else
      policy_module().policy(user, action, scope)
    end
  end

  @doc """
  Macro for consumer resource modules.

  Usage: `use Blank.Authorization, :my_resource_type`

  Saves the resource type as `@blank_resource_type` module attribute and
  imports `Blank.Authorization.can?/3` unqualified.
  """
  defmacro __using__(resource_type) when is_atom(resource_type) do
    quote do
      @blank_resource_type unquote(resource_type)
      import Blank.Authorization, only: [can?: 3]
    end
  end
end
