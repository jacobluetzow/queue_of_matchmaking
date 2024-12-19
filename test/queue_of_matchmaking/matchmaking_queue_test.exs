defmodule QueueOfMatchmaking.MatchmakingQueueTest do
  use ExUnit.Case, async: false

  setup do
    # Clear ETS tables before each test
    :ets.delete_all_objects(:matchmaking_queue)
    :ets.delete_all_objects(:matches)
    :ok
  end

  describe "add_request/2" do
    test "successfully adds valid request" do
      assert {:ok, %{ok: true, error: nil}} =
               QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)

      assert QueueOfMatchmaking.MatchmakingQueue.get_queue_size() == 1
    end

    test "rejects duplicate user" do
      QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)

      assert {:ok, %{ok: false, error: "User already in queue"}} =
               QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)
    end

    test "validates user_id" do
      assert {:ok, %{ok: false, error: "Invalid user_id or rank"}} =
               QueueOfMatchmaking.MatchmakingQueue.add_request("", 1500)
    end

    test "validates rank" do
      assert {:ok, %{ok: false, error: "Invalid user_id or rank"}} =
               QueueOfMatchmaking.MatchmakingQueue.add_request("user1", -1)
    end
  end

  describe "matchmaking" do
    test "matches users with similar ranks" do
      QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)
      QueueOfMatchmaking.MatchmakingQueue.add_request("user2", 1510)

      # Wait briefly for the match to be processed
      Process.sleep(100)

      # Queue should be empty after matching
      assert QueueOfMatchmaking.MatchmakingQueue.get_queue_size() == 0
    end

    test "expands search range when no immediate match" do
      QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)
      QueueOfMatchmaking.MatchmakingQueue.add_request("user2", 1700)

      Process.sleep(200)

      assert QueueOfMatchmaking.MatchmakingQueue.get_queue_size() == 0
    end

    test "doesn't match beyond max rank window" do
      QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1000)
      QueueOfMatchmaking.MatchmakingQueue.add_request("user2", 2000)

      Process.sleep(200)

      # Users should remain in queue as rank difference exceeds max window
      assert QueueOfMatchmaking.MatchmakingQueue.get_queue_size() == 2
    end
  end

  test "stores matches in matches table" do
    # Add two users that should match
    QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)
    QueueOfMatchmaking.MatchmakingQueue.add_request("user2", 1510)

    # Wait briefly for the match to be processed
    Process.sleep(100)

    # Check matches table
    matches = :ets.tab2list(:matches)
    assert length(matches) == 1

    # Get the first (and only) match
    [{{_user1, _user2}, match_data}] = matches
    # Assert match data structure
    assert match_data.timestamp > 0
    assert length(match_data.users) == 2

    # Check both users are present with correct ranks
    users = Enum.sort_by(match_data.users, & &1.user_id)

    assert [
             %{user_id: "user1", rank: 1500},
             %{user_id: "user2", rank: 1510}
           ] = users
  end

  test "stores multiple matches correctly" do
    # Add multiple pairs that should match
    QueueOfMatchmaking.MatchmakingQueue.add_request("user1", 1500)
    QueueOfMatchmaking.MatchmakingQueue.add_request("user2", 1510)
    Process.sleep(100)

    QueueOfMatchmaking.MatchmakingQueue.add_request("user3", 1600)
    QueueOfMatchmaking.MatchmakingQueue.add_request("user4", 1610)
    Process.sleep(100)

    # Verify both matches are stored
    matches = :ets.tab2list(:matches)
    assert length(matches) == 2

    # Verify each match has correct structure
    for {_key, match_data} <- matches do
      assert match_data.timestamp > 0
      assert length(match_data.users) == 2
      [user1, user2] = match_data.users
      # Within reasonable rank difference
      assert abs(user1.rank - user2.rank) <= 20
    end
  end
end
