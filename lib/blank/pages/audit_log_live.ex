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

    <div class="mt-12 p-10 rounded-lg bg-white dark:bg-gray-800 ring-1 ring-inset ring-gray-200 dark:ring-white/15">
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
    time_zone =
      with true <- connected?(socket),
           true <- Application.get_env(:blank, :use_local_timezone, false),
           %{"time_zone" => time_zone} <- get_connect_params(socket) do
        time_zone
      else
        _ ->
          "Etc/UTC"
      end

    {:ok, assign(socket, :time_zone, time_zone)}
  end

  @impl true
  def handle_info({:audit_log, log}, socket) do
    send_update(AuditLogComponent, id: "audit-log-component", log: log)
    {:noreply, socket}
  end
end
