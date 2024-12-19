defmodule QueueOfMatchmakingWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest

      @endpoint QueueOfMatchmakingWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
