defmodule Blank.Pages.SettingsLive do
  use Blank.Web, :live_view

  alias Blank.Context

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Settings
      <:subtitle>Manage the global settings for this application.</:subtitle>
    </.header>

    <div class="mt-12 space-y-12 divide-y">
      <div class="overflow-hidden rounded-lg ring-4 ring-rose-600">
        <div class="px-4 py-5 sm:px-6">
          <h2 class="text-2xl font-bold leading-6 text-rose-600">
            Danger Zone
          </h2>
          <p class="mt-1 text-sm text-gray-500">
            Be careful, actions in this area <strong class="underline uppercase">will</strong> 
            cause destructive actions!
          </p>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <div>
            <h4 class="text-lg font-medium text-gray-900 dark:text-white">Reset presence history</h4>
            <p class="mt-1 mb-4 text-sm text-gray-500">This will reset the presence history of ALL users.</p>
            <.button
              phx-click="reset-presence-history"
              data-confirm="Are you sure you want to reset ALL presence history?">
              Reset all
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("reset-presence-history", _params, socket) do
    {count, _} = Context.reset_presence_history(repo())

    {:noreply, put_flash(socket, :info, "Presence history has been reset for #{count} records.")}
  end

  defp repo, do: Application.fetch_env!(:blank, :repo)
end
