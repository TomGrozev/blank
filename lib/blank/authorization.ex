defmodule Blank.Authorization do
  @moduledoc """
  Authorization utilities for Blank.

  Provides role validation, the `can?/3` check and the `on_mount` authorizing
  hook. The allowed-role set, the policy module and the role mapper are owned by
  `Blank.Config`.
  """

  @doc """
  Validates that all roles in the given list are in the allowed-set.

  Returns `:ok` if all roles are allowed, or `{:error, invalid_roles}` with the
  list of disallowed atoms.

  ## Examples

      iex> validate_roles([:member])
      :ok

      iex> validate_roles([:system_admin, :unknown_role])
      {:error, [:unknown_role]}
  """
  @spec validate_roles([atom()]) :: :ok | {:error, [atom()]}
  def validate_roles(roles) when is_list(roles) do
    allowed = Blank.Config.allowed_roles()

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
      Blank.Config.policy_module().policy(user, action, scope)
    end
  end

  @doc """
  LiveView `on_mount` hook that authorizes access at mount time.

  Reads the LiveView module's `@blank_resource_type` (exposed via
  `__blank_resource_type__/0`) and fires a coarse `can?/3` check:

    * `:list` for index, import, and export actions
    * `:read` for show, edit, and new actions

  If the module has no resource type declared, the hook passes through
  with `{:cont, socket}`. On denial, the socket is halted with a redirect
  to the admin panel root.

  ## Usage

      live_session :authenticated,
        on_mount: [
          {Blank.Plugs.Auth, :ensure_authenticated},
          Blank.Audit.Context,
          {Blank.Authorization, :authorize}
        ] do
        ...
      end
  """
  @spec on_mount(:authorize, map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:authorize, _params, _session, socket) do
    view = socket.view

    if function_exported?(view, :__blank_resource_type__, 0) do
      resource_type = view.__blank_resource_type__()
      action = socket.assigns[:live_action]
      coarse_action = coarse_action(action)
      user = socket.assigns[:current_user]
      scope = %Blank.Scope{resource_type: resource_type}

      if can?(user, coarse_action, scope) do
        {:cont, socket}
      else
        prefix = socket.router.__blank_prefix__()

        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You are not authorized to access this page.")
          |> Phoenix.LiveView.redirect(to: prefix)

        {:halt, socket}
      end
    else
      {:cont, socket}
    end
  end

  defp coarse_action(action) when action in [:index, :import, :export], do: :list
  defp coarse_action(action) when action in [:show, :edit, :new], do: :read
  defp coarse_action(_), do: :read

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

      @doc false
      def __blank_resource_type__, do: @blank_resource_type
    end
  end
end
