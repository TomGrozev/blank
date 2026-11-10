defmodule Blank.Pages.AuditLogLive do
  @moduledoc false
  use Blank.Web, :live_view

  alias Blank.Components.AuditLogComponent

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Audit Logs
      <:subtitle>Displays the activity log of actions of the site.</:subtitle>
    </.header>

    <div class="mt-12 p-10 rounded-lg bg-base-200 ring-1 ring-inset ring-base-100">
      <.live_component
        id="audit-log-component"
        module={AuditLogComponent}
        main_links={@main_links}
        path_prefix={@path_prefix}
        time_zone={@time_zone}
      />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, Blank.AdminPage.put_time_zone(socket)}
  end

  @impl true
  def handle_info({:audit_log, log}, socket) do
    send_update(AuditLogComponent, id: "audit-log-component", log: log)
    {:noreply, socket}
  end
end
