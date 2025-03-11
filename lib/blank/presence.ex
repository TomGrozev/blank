defmodule Blank.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.
  """
  use Phoenix.Presence,
    otp_app: :blank,
    pubsub_server: Blank.PubSub

  def init(_opts) do
    {:ok, %{}}
  end

  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      {key,
       %{
         metas: [meta | metas],
         id: meta.id,
         schema: meta.schema,
         user: meta.name
       }}
    end
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{
        id: user_id,
        user: presence.user,
        schema: presence.schema,
        metas: Map.fetch!(presences, user_id)
      }

      msg = {__MODULE__, {:join, user_data}}
      Phoenix.PubSub.local_broadcast(Blank.PubSub, "proxy:#{topic}", msg)
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{id: user_id, user: presence.user, schema: presence.schema, metas: metas}
      msg = {__MODULE__, {:leave, user_data}}
      Phoenix.PubSub.local_broadcast(Blank.PubSub, "proxy:#{topic}", msg)
    end

    {:ok, state}
  end

  def list_online_users, do: list("online_users") |> Enum.map(fn {_id, presence} -> presence end)

  @spec track_user(struct(), String.t(), String.t() | atom()) ::
          {:ok, ref :: binary()} | {:error, reason :: term()}
  def track_user(%{id: id} = struct, name, current_page)
      when is_struct(struct) and
             is_binary(name) and (is_binary(current_page) or is_atom(current_page)) do
    track(self(), "online_users", id, %{
      id: id,
      schema: struct.__struct__,
      name: name,
      current_page: current_page,
      joined_at: :os.system_time(:seconds)
    })
  end

  def subscribe, do: Phoenix.PubSub.subscribe(Blank.PubSub, "proxy:online_users")
end
