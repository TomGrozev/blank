defmodule Blank.Pages.SettingsLive do
  use Blank.Web, :live_view

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
            <h4 class="text-lg font-medium text-gray-900 dark:text-white">Reset ALL logs</h4>
            <p class="mt-1 mb-4 text-sm text-gray-500">
              This will delete ALL audit logs. This will be locked down more in
              the future. Note that a new audit log will be created for this
              action to record who deleted the logs.
            </p>
            <.button
              phx-click="reset-audit-logs"
              data-confirm="Are you sure you want to reset ALL audit logs?"
            >
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
  def handle_event("reset-audit-logs", _params, socket) do
    {count, _} = Blank.Audit.delete_all(socket.assigns.audit_context)

    {:noreply, put_flash(socket, :info, "Deleted #{count} audit logs.")}
  end
end
