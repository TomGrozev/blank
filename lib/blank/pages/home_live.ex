defmodule Blank.Pages.HomeLive do
  @moduledoc false

  use Blank.Web, :live_view

  alias Blank.Components.AuditLogComponent

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Dashboard
    </.header>

    <div class="flex flex-col-reverse xl:grid xl:grid-rows-1 xl:grid-cols-6 gap-4 mt-4">
      <.bento_box edge="tl" large>
        <:title>Past Activity (last 10)</:title>
        <:description>
          This is the past acitivity on the site using the presence history.
        </:description>
        <.live_component
          id="audit-log-component"
          module={AuditLogComponent}
          schema_links={@schema_links}
          path_prefix={@path_prefix}
          time_zone={@time_zone}
          limit={10}
        />
      </.bento_box>
      <.bento_box edge="tr">
        <:title>Active Users</:title>
        <:description>Below is a list of active users on your site.</:description>
        <div class="flex flex-col justify-between h-full">
          <ul id="online-users" role="list" class="flex-1" phx-update="stream">
            <span class="hidden only:block text-sm text-center italic text-gray-400 pb-6">
              There are no users online :(
            </span>
            <li
              :for={
                {dom_id,
                 %{id: id, schema: schema, past_logins: past_logins, user: user, metas: metas}} <-
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
                      <.link
                        navigate={Path.join(Map.get(@schema_links, schema), to_string(id))}
                        class="text-sm font-semibold leading-6"
                      >
                        {user}
                      </.link>
                      <p
                        :for={meta <- metas}
                        class="mt-1 truncate text-xs leading-5
                        text-base-content/50"
                      >
                        {Phoenix.Naming.humanize(meta.current_page)}
                      </p>
                    </div>
                    <div>
                      <button
                        :if={!is_nil(past_logins) and !Enum.empty?(past_logins)}
                        phx-click={toggle_history(id)}
                        class="btn btn-primary btn-soft rounded-full px-2.5
                        py-1 text-xs font-semibold 
                        shadow-sm ring-1 ring-inset ring-base-100"
                      >
                        History
                      </button>
                    </div>
                  </div>
                  <div id={"history_#{id}"} class="mt-2 hidden">
                    <h3 class="text-xs text-base-content/50 uppercase font-bold tracking-tight">
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
        "flex flex-col w-full overflow-hidden rounded-lg bg-base-200 ring-1 ring-inset ring-base-100",
        @edge
      ]}>
        <div class="pt-8 px-8 pb-3 sm:px-10 sm:pt-10 sm:pb-0">
          <h3 class="text-lg tracking-tight font-medium
            mt-2">{render_slot(@title)}</h3>
          <p class="mt-2 text-sm max-w-lg text-base-content/40">
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

    schema_links = Map.new(socket.assigns.main_links, &{Map.get(&1, :schema), &1.url})

    socket =
      if connected?(socket) do
        Blank.Presence.subscribe()

        users =
          Blank.Presence.list_online_users()
          |> Enum.map(&apply_past_logins/1)

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
     |> assign(:schema_links, schema_links)
     |> assign(:view_all_presences, false)}
  end

  defp apply_past_logins(user) do
    past_logins =
      Blank.Audit.list_all_for_user(user, limit: 10)
      |> Enum.map(& &1.inserted_at)

    Map.put(user, :past_logins, past_logins)
  end

  @impl true
  def handle_event("toggle-all-presences", _, socket) do
    {:noreply, assign(socket, :view_all_presences, !socket.assigns.view_all_presences)}
  end

  @impl true
  def handle_info({Blank.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, apply_past_logins(presence))}
  end

  def handle_info({Blank.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info({:audit_log, log}, socket) do
    send_update(AuditLogComponent, id: "audit-log-component", log: log)
    {:noreply, socket}
  end
end
