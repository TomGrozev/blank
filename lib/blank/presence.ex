defmodule Blank.Presence do
  @moduledoc """
  Provides presence tracking for the Blank admin panel.

  This only tracks the presence of your frontend app and does not track the
  logged in users of the admin panel.

  To use this in your app you need to call the `track_user/3` function when the
  user navigates. This is most commonly done in a nav plug. I.e. when the user
  navigates to a new page you can easily call this function and it will update
  the user's presence.

      Blank.Presence.track_user(%User{id: 123}, "john.smith", :home)
  """

  use Phoenix.Presence,
    otp_app: :blank,
    pubsub_server: Blank.PubSub

  @type meta() :: %{
          id: String.t() | integer(),
          schema: module(),
          name: String.t(),
          current_page: String.t() | atom(),
          joined_at: integer()
        }
  @type presence() :: %{
          id: String.t() | integer(),
          metas: [meta()],
          schema: module(),
          user: String.t()
        }

  @doc false
  def child_spec(opts)

  @doc false
  def fetchers_pids()

  @impl Phoenix.Presence
  def get_by_key(topic, key)

  @impl Phoenix.Presence
  def list(topic)

  @impl Phoenix.Presence
  def track(socket, key, meta)

  @impl Phoenix.Presence
  def track(pid, topic, key, meta)

  @impl Phoenix.Presence
  def untrack(socket, key)

  @impl Phoenix.Presence
  def untrack(pid, topic, key)

  @impl Phoenix.Presence
  def update(socket, key, meta)

  @impl Phoenix.Presence
  def update(pid, topic, key, meta)

  @impl Phoenix.Presence
  def init(_opts) do
    {:ok, %{}}
  end

  @impl Phoenix.Presence
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

  @impl Phoenix.Presence
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

  @doc """
  Lists all online users

  Returns all of the presence information of online users.
  """
  @spec list_online_users() :: [presence()]
  def list_online_users, do: list("online_users") |> Enum.map(fn {_id, presence} -> presence end)

  @doc """
  Track the presence of a user

  This should be called in your nav plug for your frontend app, for example:

      Blank.Presence.track_user(%User{id: 123}, "john.smith", :home)

  ## Parameters

    * `user` - the user struct (generally would be used from the assigns for the
      logged in user)
    * `name` - the name of the user that is used for display (could be the
      email, a username, etc.)
    * `current_page` - a string or atom that represents the current page the
      user is browsing
  """
  @spec track_user(user :: struct(), name :: String.t(), current_page :: String.t() | atom()) ::
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

  @doc """
  Subscribe to updates to online users
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Blank.PubSub, "proxy:online_users")
end
