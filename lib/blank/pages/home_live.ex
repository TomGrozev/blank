defmodule Blank.Pages.HomeLive do
  @moduledoc false

  alias Blank.Context
  use Blank.Web, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Dashboard
    </.header>

    <div class="grid grid-rows-2 xl:grid-cols-6 gap-4 mt-4">
      <.bento_box edge="tl" large>
        <:title>Past Activity</:title>
        <:description>This is the past acitivity on the site using the presence history.</:description>
        <ul id="presence-history" role="list" class="space-y-6" phx-update="stream">
          <li :for={{dom_id, history} <- @streams.presence_history} id={dom_id} class="relative flex gap-x-4 group">
            <div class="absolute group-last:hidden left-0 top-0 flex w-6 justify-center -bottom-6">
              <div class="w-px bg-gray-200 dark:bg-gray-500"></div>
            </div>
            <div class="relative flex h-6 w-6 flex-none items-center justify-center bg-white dark:bg-gray-800">
              <div class="h-1.5 w-1.5 rounded-full bg-gray-100 dark:bg-gray-400 ring-1 ring-gray-300 dark:ring-gray-600"></div>
            </div>
            <p class="flex-auto py-0.5 text-xs leading-5 text-gray-500 dark:text-gray-400"><.link class="font-medium text-gray-900 dark:text-white">{history.name}</.link> logged in.</p>
            <time datetime={history.date} class="flex-none py-0.5 text-xs leading-5 text-gray-500 dark:text-gray-400">{relative_time(history.date)}</time>
          </li>
        </ul>
      </.bento_box>
      <.bento_box edge="tr">
        <:title>Active Users</:title>
        <:description>Below is a list of active users on your site.</:description>
        <div class="flex flex-col justify-between h-full">
          <ul id="online_users" role="list" class="divide-y divide-gray-100 flex-1" phx-update="stream">
            <span class="hidden only:block text-sm text-center italic text-gray-400">There are no users online :(</span>
            <li
              :for={
                {dom_id, %{id: id, past_logins: past_logins, user: user, metas: metas}} <-
                  @streams.presences
              }
              id={dom_id}
              class={[
                "items-center justify-between gap-x-6 py-5",
                if(@view_all_presences, do: "flex", else: "hidden [&:nth-child(-n+5)]:flex")
              ]}
            >
              <div class="flex w-full gap-x-4">
                <.icon name="hero-user-circle" class="w-12 h-12 flex-none bg-gray-50" />
                <div class="min-w-0 flex-auto">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-semibold leading-6 text-gray-900 dark:text-white">
                        {user}
                      </p>
                      <p
                        :for={meta <- metas}
                        class="mt-1 truncate text-xs leading-5 text-gray-500
                    dark:text-gray-400"
                      >
                        {Phoenix.Naming.humanize(meta.current_page)}
                      </p>
                    </div>
                    <div>
                      <button
                        :if={!is_nil(past_logins) and !Enum.empty?(past_logins)}
                        phx-click={toggle_history(id)}
                        class="rounded-full bg-white dark:bg-transparent px-2.5 py-1 text-xs font-semibold text-gray-900 dark:text-white shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 dark:hover:text-gray-900"
                      >
                        History
                      </button>
                    </div>
                  </div>
                  <div id={"history_#{id}"} class="mt-2 hidden">
                    <h3 class="text-xs text-gray-600 dark:text-gray-500 uppercase font-bold tracking-tight">
                      Past Logins
                    </h3>
                    <p :for={login <- past_logins || []} class="text-sm font-medium space-y-2">
                      {format_datetime(login, @time_zone)}
                    </p>
                  </div>
                </div>
              </div>
            </li>
          </ul>
          <.button class="w-full" phx-click="toggle-all-presences">
            {if @view_all_presences, do: "Hide", else: "View all"}
          </.button>
        </div>
      </.bento_box>
    </div>
    """
  end

  defp toggle_history(id) do
    JS.toggle(
      to: "#history_#{id}",
      in: {"ease-out duration-300 transform", "scale-90 opacity-0", "scale-100 opacity-100"},
      out: {"ease-in duration-300 transform", "scale-100 opacity-100", "scale-90 opacity-0"}
    )
  end

  defp format_datetime(dt, time_zone) do
    datetime = DateTime.shift_zone!(dt, time_zone, Tz.TimeZoneDatabase)

    Calendar.strftime(datetime, "%d %b %Y @ %I:%M:%S %p %Z")
  end

  defp relative_time(dt) do
    %{days: days, hours: hours, minutes: minutes, seconds: seconds} =
      calc_diff(dt, DateTime.utc_now()) |> dbg()

    cond do
      days > 0 -> format_time(days, "day")
      hours > 0 -> format_time(hours, "hour")
      minutes > 0 -> format_time(minutes, "minute")
      seconds > 0 -> format_time(seconds, "second")
      true -> "just now"
    end
  end

  defp format_time(num, type) do
    "#{num} #{plural(num, type)} ago"
  end

  defp plural(n, type) when n > 1, do: type <> "s"
  defp plural(_n, type), do: type

  defp calc_diff(first, last) do
    diff_days = last.day - first.day
    diff_hours = last.hour - first.hour
    diff_minutes = last.minute - first.minute
    diff_seconds = last.second - first.second

    %{
      days: abs(diff_days),
      hours: abs(diff_hours),
      minutes: abs(diff_minutes),
      seconds: abs(diff_seconds)
    }
  end

  attr :large, :boolean, default: false
  attr :edge, :string, default: nil
  slot :inner_block, required: true
  slot :title, required: true
  slot :description, required: true

  defp bento_box(assigns) do
    edge =
      case assigns.edge do
        "tl" -> "xl:rounded-tl-3xl"
        "tr" -> "xl:rounded-tr-3xl"
        "bl" -> "xl:rounded-bl-3xl"
        "br" -> "xl:rounded-br-3xl"
        _ -> nil
      end

    assigns = assign(assigns, :edge, edge)

    ~H"""
    <div class={["p-1", if(@large, do: "xl:col-span-4", else: "xl:col-span-2")]}>
      <div class={[
        "flex flex-col w-full h-full overflow-hidden rounded-lg bg-white dark:bg-gray-800 ring-1 ring-inset ring-gray-200 dark:ring-white/15",
        @edge
      ]}>
        <div class="pt-8 px-8 pb-3 sm:px-10 sm:pt-10 sm:pb-0">
          <h3 class="text-lg tracking-tight font-medium
            mt-2">{render_slot(@title)}</h3>
          <p class="mt-2 text-gray-600 dark:text-gray-400 text-sm max-w-lg">
            {render_slot(@description)}
          </p>
        </div>
        <div class="px-8 py-4 sm:px-10 sm:py-6 h-full">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    repo = Application.fetch_env!(:blank, :repo)

    history = Context.get_presence_history(repo)

    socket =
      if connected?(socket) do
        Blank.Presence.subscribe()
        {_schema, key} = Application.get_env(:blank, :presence_history, :past_logins)

        users =
          Blank.Presence.list_online_users()
          |> apply_past_logins(repo, key)

        stream(socket, :presences, users)
      else
        stream(socket, :presences, [])
      end

    time_zone =
      with true <- connected?(socket),
           true <- Application.get_env(:blank, :use_local_timezone, false),
           %{"time_zone" => time_zone} <- get_connect_params(socket) do
        time_zone
      else
        _ ->
          "Etc/UTC"
      end

    {:ok,
     socket
     |> assign(:time_zone, time_zone)
     |> assign(:repo, repo)
     |> assign(:view_all_presences, false)
     |> stream(:presence_history, history)}
  end

  defp apply_past_logins(users, repo, key) do
    case Stream.map(users, & &1.schema) |> Enum.uniq() do
      [schema] ->
        ids = Enum.map(users, & &1.id)

        past_logins =
          Context.list_schema_by_ids(repo, schema, ids)
          |> Map.new(fn item ->
            {item.id, Map.get(item, key)}
          end)

        Enum.map(users, fn user ->
          Map.put(user, :past_logins, Map.fetch!(past_logins, user.id))
        end)

      _ ->
        Enum.map(users, fn user ->
          item = Context.get!(repo, user.schema, user.id)

          Map.put(user, :past_logins, Map.get(item, key))
        end)
    end
  end

  @impl true
  def handle_event("toggle-all-presences", _, socket) do
    {:noreply, assign(socket, :view_all_presences, !socket.assigns.view_all_presences)}
  end

  @impl true
  def handle_info({Blank.Presence, {:join, presence}}, socket) do
    {schema, key} = Application.get_env(:blank, :presence_history, :past_logins)
    item = Context.get!(socket.assigns.repo, schema, presence.id)

    presence = Map.put(presence, :past_logins, Map.get(item, key))

    history =
      %{
        id: "presence-history-#{presence.id}-#{length(presence.past_logins)}",
        date: DateTime.utc_now(),
        name: presence.user
      }

    {:noreply,
     socket
     |> stream_insert(:presence_history, history, at: 0)
     |> stream_insert(:presences, presence)}
  end

  def handle_info({Blank.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end
end
