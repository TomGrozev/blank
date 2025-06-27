defmodule Blank.DownloadAgent do
  @moduledoc false
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add(id, path, ttl \\ 600_000) do
    GenServer.call(__MODULE__, {:add, id, path, ttl})
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def delete(id) do
    GenServer.cast(__MODULE__, {:delete, id})
  end

  # server

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    path = Map.get(state, id)

    if not is_nil(path) and File.exists?(path) do
      {:reply, {:ok, path}, state}
    else
      {:reply, {:error, "download does not exist"}, state}
    end
  end

  @impl true
  def handle_call({:add, id, path, ttl}, _from, state) do
    Process.send_after(self(), {:expire, id}, ttl)

    {:reply, {:ok, id}, Map.put(state, id, path)}
  end

  @impl true
  def handle_cast({:delete, id}, state) do
    with {:ok, path} <- Map.fetch(state, id) do
      File.rm(path)
    end

    {:noreply, Map.delete(state, id)}
  end

  @impl true
  def handle_info({:expire, id}, state), do: handle_cast({:delete, id}, state)
end
