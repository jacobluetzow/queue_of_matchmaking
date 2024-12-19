defmodule QueueOfMatchmaking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QueueOfMatchmakingWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:queue_of_matchmaking, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, [name: QueueOfMatchmaking.PubSub, adapter: Phoenix.PubSub.PG2]},
      QueueOfMatchmakingWeb.Endpoint,
      {Absinthe.Subscription, QueueOfMatchmakingWeb.Endpoint},
      QueueOfMatchmaking.MatchmakingQueue
    ]

    opts = [strategy: :one_for_one, name: QueueOfMatchmaking.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    QueueOfMatchmakingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
