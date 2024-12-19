defmodule QueueOfMatchmakingWeb.Schema.Types do
  use Absinthe.Schema.Notation

  @desc "A user in the matchmaking system"
  object :user do
    field(:user_id, non_null(:string))
    field(:rank, non_null(:integer))
  end

  object :match do
    field(:timestamp, non_null(:integer))
    field(:users, non_null(list_of(non_null(:user))))
  end

  @desc "Response for match request operations"
  object :request_response do
    field(:ok, non_null(:boolean))
    field(:error, :string)
  end

  @desc "Payload for match notifications"
  object :match_payload do
    field(:users, non_null(list_of(non_null(:user))))
  end
end
