defmodule QueueOfMatchmakingWeb.Schema do
  use Absinthe.Schema
  import_types(QueueOfMatchmakingWeb.Schema.Types)

  query do
    field :health_check, :boolean do
      resolve(fn _, _ -> {:ok, true} end)
    end
  end

  mutation do
    @desc "Add a user to the matchmaking queue"
    field :add_request, :request_response do
      arg(:user_id, non_null(:string))
      arg(:rank, non_null(:integer))

      resolve(fn %{user_id: user_id, rank: rank}, _ ->
        QueueOfMatchmaking.MatchmakingQueue.add_request(user_id, rank)
      end)
    end
  end

  subscription do
    @desc "Subscribe to match notifications for a specific user"
    field :match_found, :match_payload do
      arg(:user_id, non_null(:string))

      config(fn args, _res ->
        {:ok, topic: args.user_id}
      end)

      trigger(:match_found,
        topic: fn
          {:match_found, users} ->
            Enum.map(users, & &1.user_id)
        end
      )
    end
  end
end
