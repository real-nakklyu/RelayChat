defmodule RelayChatRealtime.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: RelayChatRealtime.PubSub},
      {Finch, name: RelayChatRealtime.Finch},
      RelayChatRealtimeWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RelayChatRealtime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RelayChatRealtimeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
