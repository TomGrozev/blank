defmodule Blank.Pages.LoginLive do
  @moduledoc false

  use Blank.Web, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-full flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <.logo class="mx-auto h-10 w-auto" />
        <h2 class="mt-6 text-center text-2xl font-bold leading-9 tracking-tight">
          Sign in to Blank admin
        </h2>
      </div>

      <div class="mt-10 sm:mx-auto sm:w-full sm:max-w-[480px]">
        <div class="bg-base-300 ring-1 ring-inset ring-base-100 px-6 pt-1 pb-12 shadow sm:rounded-lg sm:px-12">
          <%= if @local_auth_enabled do %>
            <.simple_form
              for={@form}
              id="login_form"
              class="space-y-6"
              action={Path.join(@prefix, "/log_in")}
              phx-update="ignore"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="email"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                required
              />

              <:actions>
                <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
                <div class="text-sm leading-6">
                  <a href="#" class="font-semibold text-primary opacity-75 hover:opacity-100">
                    Forgot password?
                  </a>
                </div>
              </:actions>
              <:actions>
                <.button phx-disable-with="Logging in..." class="btn btn-primary w-full">
                  Log in <span aria-hidden="true">→</span>
                </.button>
              </:actions>
            </.simple_form>
          <% end %>

          <%= if @local_auth_enabled and @ueberauth_providers != [] do %>
            <div class="relative mt-10">
              <div class="absolute inset-0 flex items-center" aria-hidden="true">
                <div class="w-full border-t border-base-100"></div>
              </div>
              <div class="relative flex justify-center text-sm font-medium leading-6">
                <span class="bg-base-300 px-6">
                  — or —
                </span>
              </div>
            </div>
          <% end %>

          <%= if @ueberauth_providers != [] do %>
            <div class={if @local_auth_enabled, do: "mt-6", else: "mt-0"}>
              <div class="space-y-3">
                <%= for {provider, _strategy} <- @ueberauth_providers do %>
                  <a
                    href={Path.join(@prefix, "/auth/#{provider}")}
                    class="btn btn-outline w-full normal-case gap-2"
                  >
                    {"Sign in with " <> Blank.Ueberauth.provider_display_name(provider)}
                  </a>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if not @local_auth_enabled and @ueberauth_providers == [] do %>
            <div class="text-center py-4">
              <p class="text-sm text-base-content/60">
                No authentication methods are configured. Please contact your administrator.
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    prefix = socket.router.__blank_prefix__()
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    local_auth_enabled? = Blank.Plugs.Auth.local_login_enabled?()

    ueberauth_providers =
      if Code.ensure_loaded?(Ueberauth) do
        Application.get_env(:ueberauth, Ueberauth, [])
        |> Keyword.get(:providers, [])
      else
        []
      end

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:prefix, prefix)
     |> assign(:local_auth_enabled, local_auth_enabled?)
     |> assign(:ueberauth_providers, ueberauth_providers), temporary_assigns: [form: form]}
  end
end
