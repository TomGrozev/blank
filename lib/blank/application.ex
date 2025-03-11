defmodule Blank.Application do
  @moduledoc false

  use Application

  def start(_, _) do
    children = [
      # {DynamicSupervisor, name: Blank.DynamicSupervisor, strategy: :one_for_one},
      {Phoenix.PubSub, name: Blank.PubSub},
      Blank.DownloadAgent,
      Blank.Presence
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
