defmodule QueueOfMatchmakingWeb.Router do
  use QueueOfMatchmakingWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :api

    forward "/api", Absinthe.Plug, schema: QueueOfMatchmakingWeb.Schema

    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: QueueOfMatchmakingWeb.Schema,
        socket: QueueOfMatchmakingWeb.UserSocket
    end
  end
end
