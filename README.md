# Queue of Matchmaking

A real-time matchmaking system built with Elixir and GraphQL that pairs users based on their skill rankings.

## Overview

Queue of Matchmaking is a skill-based matchmaking system that:
- Accepts user requests to join a matchmaking queue
- Pairs users with similar skill rankings
- Notifies matched users in real-time through GraphQL subscriptions
- Maintains data integrity during concurrent operations
- Stores all data in-memory for fast processing

## Technical Stack

- **Elixir** - Primary programming language
- **Phoenix** - Web framework
- **Absinthe** - GraphQL implementation
- **ETS** - In-memory storage

## Setup

1. Install dependencies:
```bash
mix deps.get
```

2. Start the Phoenix server:
```bash
mix phx.server
```

The GraphQL endpoint will be available at `http://localhost:4000/graphql`

## API Usage

### Adding a User to Queue

Use the `addRequest` mutation to add a user to the matchmaking queue:

```graphql
mutation {
  addRequest(userId: "Player123", rank: 1500) {
    ok
    error
  }
}
```

Response on success:
```json
{
  "data": {
    "addRequest": {
      "ok": true,
      "error": null
    }
  }
}
```

### Viewing Queue Status

Get the current state of the matchmaking queue:

```graphql
query {
  queueStatus {
    userId
    rank
  }
}
```

Response:
```json
{
  "data": {
    "queueStatus": [
      {
        "userId": "Player123",
        "rank": 1500
      },
      {
        "userId": "Player456",
        "rank": 1550
      }
    ]
  }
}
```

### Viewing Match History

Get the history of completed matches:

```graphql
query {
  matchHistory(limit: 5) {
    timestamp
    users {
      userId
      rank
    }
  }
}
```

Response:
```json
{
  "data": {
    "matchHistory": [
      {
        "timestamp": 1703001234,
        "users": [
          {
            "userId": "Player123",
            "rank": 1500
          },
          {
            "userId": "Player456",
            "rank": 1480
          }
        ]
      }
    ]
  }
}
```

### Subscribing to Match Notifications

Subscribe to match notifications for a specific user:

```graphql
subscription {
  matchFound(userId: "Player123") {
    users {
      userId
      rank
    }
  }
}
```

When a match is found, subscribers receive:
```json
{
  "data": {
    "matchFound": {
      "users": [
        {
          "userId": "Player123",
          "rank": 1500
        },
        {
          "userId": "Player456",
          "rank": 1480
        }
      ]
    }
  }
}
```

## Matchmaking Logic

The system uses an expanding window approach to create fair matches:

1. Initial matching attempts to find users within ±10 rank points
2. If no match is found, the range expands by 90 points each iteration
3. Maximum rank difference allowed is 500 points
4. Users are paired with the closest available match within the current range

This approach balances match fairness with queue times:
- Quick matches for players when similarly ranked opponents are available
- Gradually relaxed requirements to prevent excessive wait times
- Hard limit on rank difference to prevent highly mismatched games

## Implementation Details

### Data Storage

- Uses ETS tables for in-memory storage:
  - `matchmaking_queue`: Ordered set for active queue (sorted by rank)
  - `matches`: Set for completed match history
- Protected access for data integrity
- Efficient rank-based matching using ETS ordered sets

### Concurrency Handling

- GenServer manages state and synchronizes operations
- ETS provides atomic operations for queue management
- Phoenix PubSub handles real-time notifications
- Absinthe manages subscription state

## Configuration

Key configurations (in `lib/queue_of_matchmaking/matchmaking_queue.ex`):
```elixir
@initial_rank_window 10      # Initial search window (±10)
@rank_window_increment 90    # Window expansion per iteration
@max_rank_window 500        # Maximum allowed rank difference
```

These values can be adjusted to balance match quality vs. queue times.

## Testing

Run the test suite:
```bash
mix test
```

Tests cover:
- Queue operations
- Match processing
- GraphQL mutations and queries
- Real-time subscriptions
- Concurrent request handling
- Edge cases and validation

## Development

To start development:

1. Clone the repository
2. Install dependencies with `mix deps.get`
3. Start Phoenix endpoint with `mix phx.server`
4. Visit `http://localhost:4000/graphiql` for interactive GraphQL explorer

## License

MIT License - See LICENSE file for details