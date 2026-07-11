defmodule Blank.Pages.UsersLive do
  @moduledoc false
  alias Blank.Accounts.User
  alias Blank.Scope

  use Blank.AdminPage,
    schema: User,
    icon: "hero-user",
    index_fields: [:id, :email],
    name: "user",
    plural_name: "users"

  defoverridable mount: 3, render: 1, handle_event: 3

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    {:ok, socket} = super(params, session, socket)

    if can?(socket.assigns.current_user, :update, %Scope{resource_type: :user}) do
      {:ok, socket}
    else
      prefix = socket.router.__blank_prefix__()

      socket =
        socket
        |> put_flash(:error, "You are not authorized to edit users.")
        |> redirect(to: prefix)

      {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <h2>Edit roles for {@item.email}</h2>
    <.simple_form for={%{}} phx-submit="save_roles">
      <%= for role <- allowed_roles() do %>
        <label>
          <input
            type="checkbox"
            name="roles[]"
            value={role}
            checked={role in @item.roles}
          />
          {role}
        </label>
      <% end %>
      <:actions>
        <.button type="submit">Update roles</.button>
      </:actions>
    </.simple_form>
    """
  end

  def render(assigns), do: super(assigns)

  @impl Phoenix.LiveView
  def handle_event("save_roles", params, socket) do
    if can?(socket.assigns.current_user, :update, %Scope{resource_type: :user}) do
      roles =
        Map.get(params, "roles", [])
        |> Enum.map(&String.to_existing_atom/1)

      update_user_roles(socket, roles)
    else
      {:noreply,
       socket
       |> put_flash(:error, "You are not authorized to edit users.")
       |> push_patch(to: socket.assigns.active_link.url)}
    end
  end

  def handle_event(event, params, socket), do: super(event, params, socket)

  defp update_user_roles(socket, roles) do
    case Blank.Accounts.update_roles(socket.assigns.item, roles,
           source: "admin_ui",
           audit_context: socket.assigns.audit_context
         ) do
      {:ok, _user} ->
        socket
        |> put_flash(:info, "Roles updated successfully")
        |> push_patch(to: socket.assigns.active_link.url)
        |> then(&{:noreply, &1})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
          |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)

        socket
        |> put_flash(:error, "Failed to update roles: #{errors}")
        |> push_patch(to: socket.assigns.active_link.url)
        |> then(&{:noreply, &1})
    end
  end

  defp allowed_roles do
    Blank.Authorization.allowed_roles()
    |> Enum.sort()
  end
end
