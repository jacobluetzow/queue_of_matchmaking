defmodule QueueOfMatchmakingWeb.SubscriptionCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case
      import Phoenix.ChannelTest
      import Absinthe.Phoenix.SubscriptionTest
      # Add explicit import for the assert functions
      import Phoenix.ChannelTest,
        only: [
          assert_push: 2,
          assert_push: 3,
          refute_push: 2,
          refute_push: 3
        ]

      @endpoint QueueOfMatchmakingWeb.Endpoint

      setup do
        :ets.delete_all_objects(:matchmaking_queue)
        :ets.delete_all_objects(:matches)
        {:ok, socket} = Phoenix.ChannelTest.connect(QueueOfMatchmakingWeb.UserSocket, %{})
        {:ok, socket: socket}
      end

      def subscribe_to_match(socket, user_id) do
        subscription = """
        subscription ($userId: String!) {
          matchFound(userId: $userId) {
            users {
              userId
              rank
            }
          }
        }
        """

        ref = push_doc(socket, subscription, variables: %{"userId" => user_id})
        assert_reply ref, :ok, %{subscriptionId: subscription_id}

        subscription_id
      end
    end
  end
end
