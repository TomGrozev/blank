defmodule DemoApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DemoApp.Repo,
      DemoAppWeb.Telemetry,
      {Phoenix.PubSub, name: DemoApp.PubSub},
      DemoAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DemoApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DemoAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
