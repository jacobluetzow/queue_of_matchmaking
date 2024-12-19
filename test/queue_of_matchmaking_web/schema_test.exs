defmodule QueueOfMatchmakingWeb.SchemaTest do
  use ExUnit.Case
  use Absinthe.Phoenix.SubscriptionTest, schema: QueueOfMatchmakingWeb.Schema

  import Phoenix.ChannelTest,
    only: [
      connect: 2,
      assert_reply: 3
    ]

  @endpoint QueueOfMatchmakingWeb.Endpoint

  setup do
    :ets.delete_all_objects(:matchmaking_queue)
    :ets.delete_all_objects(:matches)
    :ok
  end

  @add_request_mutation """
  mutation AddRequest($userId: String!, $rank: Int!) {
    addRequest(userId: $userId, rank: $rank) {
      ok
      error
    }
  }
  """

  @subscription_doc """
  subscription($userId: String!) {
    matchFound(userId: $userId) {
      users {
        userId
        rank
      }
    }
  }
  """

  describe "mutations" do
    test "addRequest adds user to queue" do
      result =
        Absinthe.run!(
          @add_request_mutation,
          QueueOfMatchmakingWeb.Schema,
          variables: %{"userId" => "test_user", "rank" => 1500}
        )

      assert %{
               data: %{
                 "addRequest" => %{
                   "ok" => true,
                   "error" => nil
                 }
               }
             } = result

      assert QueueOfMatchmaking.MatchmakingQueue.get_queue_size() == 1
    end

    test "addRequest validates input" do
      result =
        Absinthe.run!(
          @add_request_mutation,
          QueueOfMatchmakingWeb.Schema,
          variables: %{"userId" => "", "rank" => 1500}
        )

      assert %{
               data: %{
                 "addRequest" => %{
                   "ok" => false,
                   "error" => "Invalid user_id or rank"
                 }
               }
             } = result
    end

    test "addRequest prevents duplicate users" do
      # Add first request
      first_result =
        Absinthe.run!(
          @add_request_mutation,
          QueueOfMatchmakingWeb.Schema,
          variables: %{"userId" => "test_user", "rank" => 1500}
        )

      # Verify first request succeeded
      assert %{
               data: %{
                 "addRequest" => %{
                   "ok" => true,
                   "error" => nil
                 }
               }
             } = first_result

      Process.sleep(50)

      # Try to add same user again
      second_result =
        Absinthe.run!(
          @add_request_mutation,
          QueueOfMatchmakingWeb.Schema,
          variables: %{"userId" => "test_user", "rank" => 1600}
        )

      assert %{
               data: %{
                 "addRequest" => %{
                   "ok" => false,
                   "error" => "User already in queue"
                 }
               }
             } = second_result
    end
  end

  describe "subscriptions" do
    test "notifies matched users" do
      # Set up subscriptions
      socket_1 = build_socket()
      socket_2 = build_socket()

      # Subscribe both users
      ref1 = push_doc(socket_1, @subscription_doc, variables: %{"userId" => "user1"})
      ref2 = push_doc(socket_2, @subscription_doc, variables: %{"userId" => "user2"})

      assert_reply ref1, :ok, %{}
      assert_reply ref2, :ok, %{}

      # Add users to queue
      Absinthe.run!(
        @add_request_mutation,
        QueueOfMatchmakingWeb.Schema,
        variables: %{"userId" => "user1", "rank" => 1500}
      )

      Absinthe.run!(
        @add_request_mutation,
        QueueOfMatchmakingWeb.Schema,
        variables: %{"userId" => "user2", "rank" => 1510}
      )

      # Check for match notification with more flexible assertion
      assert_receive %Phoenix.Socket.Message{
                       event: "subscription:data",
                       payload: %{
                         result: %{
                           data: %{
                             "matchFound" => %{
                               "users" => users
                             }
                           }
                         }
                       }
                     },
                     1000

      # Verify the users list contains both users in any order
      assert length(users) == 2

      assert Enum.sort_by(users, & &1["userId"]) == [
               %{"userId" => "user1", "rank" => 1500},
               %{"userId" => "user2", "rank" => 1510}
             ]
    end

    test "only notifies relevant users" do
      # Set up spectator subscription
      socket = build_socket()
      ref = push_doc(socket, @subscription_doc, variables: %{"userId" => "spectator"})
      assert_reply ref, :ok, %{}

      # Add two other users that should match
      Absinthe.run!(
        @add_request_mutation,
        QueueOfMatchmakingWeb.Schema,
        variables: %{"userId" => "player1", "rank" => 1500}
      )

      Absinthe.run!(
        @add_request_mutation,
        QueueOfMatchmakingWeb.Schema,
        variables: %{"userId" => "player2", "rank" => 1510}
      )

      # Verify spectator receives no notification
      refute_receive %{
                       event: "subscription:data"
                     },
                     1000
    end
  end

  defp build_socket do
    {:ok, socket} = connect(QueueOfMatchmakingWeb.UserSocket, %{})
    {:ok, socket} = Absinthe.Phoenix.SubscriptionTest.join_absinthe(socket)
    socket
  end
end
