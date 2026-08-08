defmodule Blank.Components.AuditLogComponent do
  @moduledoc false
  use Blank.Web, :live_component

  alias Blank.Audit
  alias Blank.Audit.AuditLog

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flow-root">
      <ul id={@id} role="list" class="-mb-8" phx-update="stream">
        <li :for={{dom_id, log} <- @streams.logs} id={dom_id} class="group">
          <div class="relative pb-8">
            <span
              class="absolute group-last:hidden left-4 top-4 -ml-px h-full w-0.5 bg-base-200"
              aria-hidden="true"
            >
            </span>
            <div class="relative flex space-x-3">
              <div>
                <span class={"h-8 w-8 rounded-full #{audit_colour(log)} flex items-center justify-center"}>
                  <.icon class="h-5 w-5" name={audit_icon(log)} />
                </span>
              </div>
              <details class="flex flex-col min-w-0 flex-1 pt-1.5">
                <summary class="flex flex-col lg:flex-row justify-between lg:space-x-4">
                  <p class="text-sm text-base-content/60">
                    {audit_text(log, @path_prefix, @schema_links)}
                  </p>
                  <div class="whitespace-nowrap text-left lg:text-right text-sm italic lg:not-italic text-base-content/60">
                    <time datetime={log.inserted_at}>
                      {format_datetime(log.inserted_at, @time_zone)}
                    </time>
                  </div>
                </summary>
                <table class="mt-2">
                  <tr>
                    <td class="font-medium whitespace-nowrap pr-4">
                      User Agent:
                    </td>
                    <td class="text-sm text-base-content/40">{log.user_agent}</td>
                  </tr>
                  <tr>
                    <td class="font-medium whitespace-nowrap pr-4">
                      IP:
                    </td>
                    <td class="text-sm text-base-content/40">
                      {format_ip(log.ip_address)}
                    </td>
                  </tr>
                </table>
              </details>
            </div>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  @impl true
  def update(%{log: log}, socket) do
    {:ok, stream_insert(socket, :logs, log, at: 0)}
  end

  def update(assigns, socket) do
    logs =
      Audit.list_all(limit: Map.get(assigns, :limit, 50))

    schema_links =
      Map.get_lazy(assigns, :schema_links, fn ->
        Map.new(assigns.main_links, &{Map.get(&1, :schema), &1.url})
      end)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blank.PubSub, "audit:logs")
    end

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

  @doc false
  @spec audit_text(AuditLog.t(), String.t(), map(), String.t() | nil) :: String.t()
  def audit_text(log, prefix, schema_links, type \\ nil)

  def audit_text(%{action: "accounts.login"} = log, prefix, schema_links, _type) do
    identified_text("logged in", log, prefix, schema_links)
  end

  def audit_text(%{action: "accounts.login_failed"} = log, prefix, schema_links, _type) do
    email = Map.get(log.params, "email", Map.get(log.params, :email, "unknown"))
    reason = Map.get(log.params, "reason", Map.get(log.params, :reason, "unknown"))
    {username, _type, _path} = identity(log, prefix, schema_links)
    assigns = %{username: username, email: email, reason: reason}

    ~H"""
    <span class="font-medium text-base-content">{@username}</span>
    failed login for {@email} (reason: {@reason})
    """
  end

  def audit_text(%{action: "accounts.logout"} = log, prefix, schema_links, _type) do
    identified_text("logged out", log, prefix, schema_links)
  end

  def audit_text(%{action: "accounts.user_created"} = log, prefix, schema_links, _type) do
    identified_text("created a user", log, prefix, schema_links)
  end

  def audit_text(
        %{action: "*.create", params: %{"item_id" => item_id}} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text(
      "created a #{Phoenix.Naming.humanize(type)} (ID: #{item_id})",
      log,
      prefix,
      schema_links
    )
  end

  def audit_text(
        %{action: "*.create_multiple", params: %{"item_ids" => item_ids}} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text(
      "created multiple #{Phoenix.Naming.humanize(type)} (IDs: #{Enum.join(item_ids, ", ")})",
      log,
      prefix,
      schema_links
    )
  end

  def audit_text(
        %{action: "*.update", params: %{"item_id" => item_id}} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text(
      "updated a #{Phoenix.Naming.humanize(type)} (ID: #{item_id})",
      log,
      prefix,
      schema_links
    )
  end

  def audit_text(
        %{action: "*.update_multiple", params: %{"item_ids" => item_ids}} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text(
      "updated multiple #{Phoenix.Naming.humanize(type)} (IDs: #{Enum.join(item_ids, ", ")})",
      log,
      prefix,
      schema_links
    )
  end

  def audit_text(
        %{action: "*.delete", params: %{"item_id" => item_id}} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text(
      "deleted a #{Phoenix.Naming.humanize(type)} (ID: #{item_id})",
      log,
      prefix,
      schema_links
    )
  end

  def audit_text(
        %{action: "*.delete_all"} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text("deleted all #{Phoenix.Naming.humanize(type)}", log, prefix, schema_links)
  end

  def audit_text(%{action: "*." <> sub_action = full_action}, _, _, type) do
    action =
      if is_nil(type) do
        full_action
      else
        "#{type}.#{sub_action}"
      end

    raise ArgumentError, "invalid action supplied: #{action}"
  end

  def audit_text(%{action: action} = log, prefix, schema_links, _type) do
    {star_action, type} = star(action)

    log
    |> Map.update!(:params, fn params ->
      Map.new(params, fn {k, v} -> {to_string(k), v} end)
    end)
    |> Map.put(:action, star_action)
    |> audit_text(prefix, schema_links, type)
  end

  defp identified_text(text, log, prefix, schema_links) do
    {username, type, path} = identity(log, prefix, schema_links)
    assigns = %{text: text, username: username, type: type, user_path: path}

    if is_nil(path) do
      ~H"""
      <span class="font-medium text-base-content">{@username} ({@type})</span> {@text}
      """
    else
      ~H"""
      <span>
        <.link class="font-medium text-base-content" navigate={@user_path}>
          {@username} ({@type})
        </.link>
        {@text}
      </span>
      """
    end
  end

  defp identity(%{user: nil, user_agent: "SYSTEM"}, _prefix, _schema_links),
    do: {"SYSTEM", "system", nil}

  defp identity(%{user: user}, _prefix, schema_links) when not is_nil(user) do
    schema = user.__struct__
    username = Blank.Schema.name(user)

    path =
      if url = Map.get(schema_links, schema) do
        Path.join([url, get_user_id(user)])
      end

    {username, "user", path}
  end

  defp get_user_id(user) do
    Map.fetch!(user, :id)
    |> to_string()
  end

  @doc false
  @spec audit_icon(AuditLog.t()) :: String.t()
  def audit_icon(%{action: "accounts.login"}), do: "hero-arrow-right-end-on-rectangle"
  def audit_icon(%{action: "accounts.login_failed"}), do: "hero-x-circle"
  def audit_icon(%{action: "accounts.logout"}), do: "hero-arrow-left-start-on-rectangle"
  def audit_icon(%{action: "accounts.user_created"}), do: "hero-user-plus"
  def audit_icon(%{action: "*.create"}), do: "hero-plus"
  def audit_icon(%{action: "*.create_multiple"}), do: "hero-plus"
  def audit_icon(%{action: "*.update"}), do: "hero-pencil"
  def audit_icon(%{action: "*.update_multiple"}), do: "hero-pencil"
  def audit_icon(%{action: "*.delete"}), do: "hero-trash"
  def audit_icon(%{action: "*.delete_all"}), do: "hero-trash"
  def audit_icon(%{action: "*." <> _}), do: "hero-information-circle-solid"

  def audit_icon(%{action: action} = log) do
    {star_action, _type} = star(action)

    Map.put(log, :action, star_action)
    |> audit_icon()
  end

  @doc false
  @spec audit_colour(AuditLog.t()) :: String.t()
  def audit_colour(%{action: "accounts." <> _}), do: "bg-emerald-400"
  def audit_colour(%{action: "*.create"}), do: "bg-blue-400"
  def audit_colour(%{action: "*.create_multiple"}), do: "bg-blue-400"
  def audit_colour(%{action: "*.update"}), do: "bg-sky-400"
  def audit_colour(%{action: "*.update_multiple"}), do: "bg-sky-400"
  def audit_colour(%{action: "*.delete"}), do: "bg-rose-400"
  def audit_colour(%{action: "*.delete_all"}), do: "bg-rose-400"
  def audit_colour(%{action: "*." <> _}), do: "bg-gray-400"

  def audit_colour(%{action: action} = log) do
    {star_action, _type} = star(action)

    Map.put(log, :action, star_action)
    |> audit_colour()
  end

  defp star(action) do
    [type, sub_action] = String.split(action, ".", parts: 2)
    star_action = "*.#{sub_action}"

    {star_action, type}
  end
end
