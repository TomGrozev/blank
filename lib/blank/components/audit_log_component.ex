defmodule Blank.Components.AuditLogComponent do
  use Blank.Web, :live_component

  alias Blank.Audit

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow-root">
      <ul id={@id} role="list" class="-mb-8" phx-update="stream">
        <li id={dom_id} :for={{dom_id, log} <- @streams.logs} class="group">
          <div class="relative pb-8">
            <span class="absolute group-last:hidden left-4 top-4 -ml-px h-full w-0.5 bg-gray-200 dark:bg-gray-600" aria-hidden="true"></span>
            <div class="relative flex space-x-3">
              <div>
                <span class={"h-8 w-8 rounded-full #{Blank.Audit.Display.colour(log)} flex items-center justify-center ring-8 ring-white dark:ring-gray-800"}>
                  <.icon class="h-5 w-5" name={Blank.Audit.Display.icon(log)} />
                </span>
              </div>
              <div class="flex min-w-0 flex-1 justify-between space-x-4 pt-1.5">
                <div>
                  <p class="text-sm text-gray-500 dark:text-gray-400">{Blank.Audit.Display.text(log, @path_prefix, @schema_links)}</p>
                  <div>
                    <p class="text-sm text-gray-500 dark:text-gray-400">User Agent: {log.user_agent}</p>
                    <p class="text-sm text-gray-500 dark:text-gray-400">IP: {format_ip(log.ip_address)}</p>
                  </div>
                </div>
                <div class="whitespace-nowrap text-right text-sm text-gray-500 dark:text-gray-400">
                  <time datetime={log.inserted_at}>{format_datetime(log.inserted_at, @time_zone)}</time>
                </div>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    logs =
      Audit.list_all(limit: Map.get(assigns, :limit, 50))

    schema_links =
      Map.get_lazy(assigns, :schema_links, fn ->
        Map.new(assigns.main_links, &{Map.get(&1, :schema), &1.url})
      end)

    {:ok,
     socket
     |> assign(Map.take(assigns, [:id, :path_prefix, :time_zone]))
     |> assign(:schema_links, schema_links)
     |> stream(:logs, logs, reset: true)}
  end

  defp format_datetime(dt, time_zone) do
    datetime = DateTime.shift_zone!(dt, time_zone, Tz.TimeZoneDatabase)

    Calendar.strftime(datetime, "%d %b %Y @ %I:%M:%S %p %Z")
  end

  defp format_ip(nil), do: ""

  defp format_ip(ip) when is_tuple(ip) do
    ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp format_ip(ip) when is_binary(ip), do: ip
end
