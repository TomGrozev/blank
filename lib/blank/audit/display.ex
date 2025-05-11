defmodule Blank.Audit.Display do
  @moduledoc """
  Methods to display audit log messages correctly
  """

  import Phoenix.Component

  @doc """
  Returns descriptive text for the log type
  """
  def text(log, prefix, schema_links, type \\ nil)

  def text(%{action: "accounts.login"} = log, prefix, schema_links, _type) do
    identified_text("logged in", log, prefix, schema_links)
  end

  def text(
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

  def text(
        %{action: "*.create_multiple", params: %{"item_id" => item_id}} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text(
      "created multiple #{Phoenix.Naming.humanize(type)} (IDs: #{Enum.join(item_id, ", ")})",
      log,
      prefix,
      schema_links
    )
  end

  def text(
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

  def text(
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

  def text(
        %{action: "*.delete_all"} = log,
        prefix,
        schema_links,
        type
      ) do
    identified_text("deleted all #{Phoenix.Naming.humanize(type)}", log, prefix, schema_links)
  end

  def text(%{action: "*." <> sub_action = full_action}, _, _, type) do
    action =
      if is_nil(type) do
        full_action
      else
        "#{type}.#{sub_action}"
      end

    raise ArgumentError, "invalid action supplied: #{action}"
  end

  def text(%{action: action} = log, prefix, schema_links, _type) do
    {star_action, type} = star(action)

    log
    |> Map.put(:action, star_action)
    |> text(prefix, schema_links, type)
  end

  defp identified_text(text, log, prefix, schema_links) do
    {username, type, path} = identity(log, prefix, schema_links)
    assigns = %{text: text, username: username, type: type, user_path: path}

    if is_nil(path) do
      ~H"""
      <span class="font-medium text-gray-900 dark:text-white">{@username} ({@type})</span> {@text}
      """
    else
      ~H"""
      <.link class="font-medium text-gray-900 dark:text-white" navigate={@user_path}>{@username} ({@type})</.link> {@text}
      """
    end
  end

  defp identity(%{admin: admin, user: nil}, prefix, _schema_links) when not is_nil(admin) do
    username = Blank.Schema.name(admin)

    {username, "admin", Path.join([prefix, "/admins", to_string(admin.id)])}
  end

  defp identity(%{admin: nil, user: user}, _prefix, schema_links) when not is_nil(user) do
    schema = user.__struct__
    username = Blank.Schema.name(user)

    path =
      if url = Map.get(schema_links, schema) do
        Path.join([url, to_string(user.id)])
      end

    {username, "user", path}
  end

  defp identity(%{admin: nil, user: nil, user_agent: "SYSTEM"}), do: {"SYSTEM", "system", nil}

  @doc """
  Returns the icon name for a log type
  """
  def icon(%{action: "accounts.login"}), do: "hero-arrow-right-end-on-rectangle"
  def icon(%{action: "accounts.logout"}), do: "hero-arrow-left-start-on-rectangle"
  def icon(%{action: "*.create"}), do: "hero-plus"
  def icon(%{action: "*.create_multiple"}), do: "hero-plus"
  def icon(%{action: "*.update"}), do: "hero-pencil"
  def icon(%{action: "*.delete"}), do: "hero-trash"
  def icon(%{action: "*.delete_all"}), do: "hero-trash"
  def icon(%{action: "*." <> _}), do: "hero-information-circle-solid"

  def icon(%{action: action} = log) do
    {star_action, _type} = star(action)

    Map.put(log, :action, star_action)
    |> icon()
  end

  @doc """
  Returns the colour for the log type
  """
  def colour(%{action: "accounts." <> _}), do: "bg-emerald-400"
  def colour(%{action: "*.create"}), do: "bg-blue-400"
  def colour(%{action: "*.create_multiple"}), do: "bg-blue-400"
  def colour(%{action: "*.update"}), do: "bg-sky-400"
  def colour(%{action: "*.delete"}), do: "bg-rose-400"
  def colour(%{action: "*.delete_all"}), do: "bg-rose-400"
  def colour(%{action: "*." <> _}), do: "bg-gray-400"

  def colour(%{action: action} = log) do
    {star_action, _type} = star(action)

    Map.put(log, :action, star_action)
    |> colour()
  end

  defp star(action) do
    [type, sub_action] = String.split(action, ".", parts: 2)
    star_action = "*.#{sub_action}"

    {star_action, type}
  end
end
