defmodule Blank.Pages.ProfileLive do
  @moduledoc false
  use Blank.Web, :live_view

  alias Blank.Accounts

  @doc false
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>
        Manage your account
      </:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <%= if ueberauth_user?(@current_user) do %>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <h3 class="card-title text-lg">Identity Provider</h3>
            <div class="space-y-3">
              <div class="flex justify-between items-center py-2 border-b border-base-300">
                <span class="text-sm font-medium text-base-content/60">Provider</span>
                <span class="text-sm text-base-content">
                  {Blank.Ueberauth.provider_display_name(@current_user.provider)}
                </span>
              </div>
              <div class="flex justify-between items-center py-2 border-b border-base-300">
                <span class="text-sm font-medium text-base-content/60">External ID</span>
                <span class="text-sm text-base-content">{@current_user.external_uid}</span>
              </div>
              <div class="flex justify-between items-center py-2 border-b border-base-300">
                <span class="text-sm font-medium text-base-content/60">Email</span>
                <span class="text-sm text-base-content">{@current_user.email}</span>
              </div>
              <div class="flex justify-between items-center py-2">
                <span class="text-sm font-medium text-base-content/60">Name</span>
                <span class="text-sm text-base-content">{@current_user.name}</span>
              </div>
            </div>
            <div class="mt-4 p-3 bg-base-300 rounded-lg">
              <p class="text-sm text-base-content/60">
                Your account is managed by <strong>{Blank.Ueberauth.provider_display_name(@current_user.provider)}</strong>.
                Password changes must be made through your identity provider.
              </p>
            </div>
          </div>
        </div>
      <% else %>
        <div>
          <.simple_form
            for={@password_form}
            id="password_form"
            action={Path.join(@path_prefix, "/log_in?_action=password_updated")}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              value={@current_email}
            />
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              id="current_password_for_password"
              value={@current_password}
              required
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              required
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Password</.button>
            </:actions>
          </.simple_form>
        </div>
      <% end %>
    </div>
    """
  end

  @doc false
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      if ueberauth_user?(user) do
        socket
        |> assign(:current_email, user.email)
      else
        password_changeset = Accounts.change_user_password(user)

        socket
        |> assign(:current_password, nil)
        |> assign(:email_form_current_password, nil)
        |> assign(:current_email, user.email)
        |> assign(:password_form, to_form(password_changeset))
        |> assign(:trigger_submit, false)
      end

    {:ok, socket}
  end

  @doc false
  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp ueberauth_user?(%{provider: provider}) when is_binary(provider) and provider != "",
    do: true

  defp ueberauth_user?(_), do: false
end
