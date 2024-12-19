defmodule QueueOfMatchmakingWeb.Schema do
  use Absinthe.Schema
  import_types(QueueOfMatchmakingWeb.Schema.Types)

  query do
    @desc "Get current queue status"
    field :queue_status, list_of(:user) do
      resolve(fn _, _ ->
        queue_entries = :ets.tab2list(:matchmaking_queue)

        users =
          Enum.map(queue_entries, fn {{_rank, user_id}, rank} ->
            %{user_id: user_id, rank: rank}
          end)

        {:ok, users}
      end)
    end

    @desc "Get match history"
    field :match_history, list_of(:match) do
      arg(:limit, :integer, default_value: 10)

      resolve(fn %{limit: limit}, _ ->
        matches =
          :ets.tab2list(:matches)
          |> Enum.map(fn {_key, match_data} -> match_data end)
          |> Enum.sort_by(& &1.timestamp, :desc)
          |> Enum.take(limit)

        {:ok, matches}
      end)
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
