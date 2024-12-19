defmodule QueueOfMatchmaking.MatchmakingQueue do
  use GenServer

  @queue_table_name :matchmaking_queue
  @matches_table_name :matches
  # Start looking for matches within ±10 rank
  @initial_rank_window 10
  # Increment by this amount each expansion
  @rank_window_increment 90
  # Maximum rank difference to consider
  @max_rank_window 500

  defp table_access do
    if Mix.env() == :test, do: :public, else: :protected
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    IO.puts("Matchmaking Queue Server Starting...")
    # Use ordered_set for automatic rank ordering
    queue_table = :ets.new(@queue_table_name, [:ordered_set, table_access(), :named_table])
    matches_table = :ets.new(@matches_table_name, [:set, table_access(), :named_table])

    {:ok,
     %{
       queue_table: queue_table,
       matches_table: matches_table
     }}
  end

  def add_request(user_id, rank) do
    GenServer.call(__MODULE__, {:add_request, user_id, rank})
  end

  def get_queue_size do
    GenServer.call(__MODULE__, :get_queue_size)
  end

  def remove_request(user_id) do
    GenServer.call(__MODULE__, {:remove_request, user_id})
  end

  def handle_call({:add_request, user_id, rank}, _from, state) do
    with {:ok, :validated} <- validate_request(user_id, rank),
         :ok <- add_to_queue(user_id, rank) do
      GenServer.cast(self(), {:process_match, user_id, rank})
      {:reply, {:ok, %{ok: true, error: nil}}, state}
    else
      {:error, reason} ->
        {:reply, {:ok, %{ok: false, error: reason}}, state}
    end
  end

  def handle_call(:get_queue_size, _from, state) do
    size = :ets.info(@queue_table_name, :size)
    {:reply, size, state}
  end

  def handle_call({:remove_request, user_id}, _from, state) do
    remove_from_queue(user_id)
    {:reply, :ok, state}
  end

  def handle_cast({:process_match, user_id, rank}, state) do
    case find_match(user_id, rank) do
      {:match_found, matched_user} ->
        remove_from_queue(user_id)
        remove_from_queue(matched_user.user_id)

        store_match(user_id, rank, matched_user.user_id, matched_user.rank)

        Absinthe.Subscription.publish(
          QueueOfMatchmakingWeb.Endpoint,
          %{
            users: [
              %{user_id: user_id, rank: rank},
              %{user_id: matched_user.user_id, rank: matched_user.rank}
            ]
          },
          match_found: [user_id, matched_user.user_id]
        )

      :no_match ->
        :ok
    end

    {:noreply, state}
  end

  defp validate_request(user_id, rank)
       when is_binary(user_id) and user_id != "" and is_integer(rank) and rank >= 0 do
    {:ok, :validated}
  end

  defp validate_request(_, _), do: {:error, "Invalid user_id or rank"}

  defp add_to_queue(user_id, rank) do
    # First check if user exists with any rank using match specification
    match_spec = [
      {
        # Match any rank with this user_id
        {{:"$1", user_id}, :"$2"},
        # No conditions
        [],
        # Return true if found
        [true]
      }
    ]

    case :ets.select(@queue_table_name, match_spec) do
      [] ->
        :ets.insert(@queue_table_name, {{rank, user_id}, rank})
        :ok

      [_ | _] ->
        {:error, "User already in queue"}
    end
  end

  defp remove_from_queue(user_id) do
    match_spec = [
      {
        {{:"$1", :"$2"}, :"$3"},
        [{:"=:=", :"$2", user_id}],
        [:"$_"]
      }
    ]

    entries = :ets.select(@queue_table_name, match_spec)
    Enum.each(entries, &:ets.delete_object(@queue_table_name, &1))
  end

  defp find_match(user_id, rank) do
    find_match_in_window(user_id, rank, @initial_rank_window)
  end

  defp find_match_in_window(user_id, rank, window) when window <= @max_rank_window do
    min_rank = max(0, rank - window)
    max_rank = rank + window

    IO.puts("Looking for matches for rank #{rank} between #{min_rank} and #{max_rank}")

    case find_nearest_match(min_rank, max_rank, user_id) do
      {:ok, matched_user} ->
        {:match_found, matched_user}

      :no_match ->
        find_match_in_window(user_id, rank, window + @rank_window_increment)
    end
  end

  defp find_match_in_window(_, _, _), do: :no_match

  defp find_nearest_match(min_rank, max_rank, excluding_user_id) do
    case find_starting_key(max_rank) do
      :"$end_of_table" ->
        :no_match

      key ->
        collect_matches(key, min_rank, max_rank, excluding_user_id, [])
    end
  end

  defp find_starting_key(max_rank) do
    case :ets.next(@queue_table_name, {max_rank, ""}) do
      :"$end_of_table" ->
        :ets.prev(@queue_table_name, {max_rank + 1, ""})

      next_key ->
        :ets.prev(@queue_table_name, next_key)
    end
  end

  defp collect_matches(:"$end_of_table", min_rank, _max_rank, _excluding_user_id, acc),
    do: format_matches(acc, min_rank)

  defp collect_matches(key = {rank, user_id}, min_rank, max_rank, excluding_user_id, acc)
       when rank >= min_rank and rank <= max_rank do
    new_acc =
      if user_id != excluding_user_id do
        case :ets.lookup(@queue_table_name, key) do
          [{_key, rank}] -> [{user_id, rank} | acc]
          [] -> acc
        end
      else
        acc
      end

    collect_matches(
      :ets.prev(@queue_table_name, key),
      min_rank,
      max_rank,
      excluding_user_id,
      new_acc
    )
  end

  defp collect_matches({rank, _}, min_rank, _max_rank, _excluding_user_id, acc)
       when rank < min_rank,
       do: format_matches(acc, min_rank)

  defp format_matches([], _min_rank), do: :no_match

  defp format_matches(matches, min_rank) do
    {user_id, rank} = Enum.min_by(matches, fn {_, rank} -> abs(rank - min_rank) end)
    {:ok, %{user_id: user_id, rank: rank}}
  end

  defp store_match(user1_id, rank1, user2_id, rank2) do
    match_data = %{
      timestamp: System.system_time(:second),
      users: [
        %{user_id: user1_id, rank: rank1},
        %{user_id: user2_id, rank: rank2}
      ]
    }

    :ets.insert(@matches_table_name, {{user1_id, user2_id}, match_data})
  end
end
