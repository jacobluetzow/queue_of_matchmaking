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

Response on error:
```json
{
  "data": {
    "addRequest": {
      "ok": false,
      "error": "User already in queue"
    }
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

The system uses the following strategy to create fair matches:

1. Initial matching attempts to find users within ±10 rank points
2. If no match is found, the range expands by 90 points each iteration
3. Maximum rank difference allowed is 500 points
4. Users are paired with the closest available match within the current range

## Implementation Details

### Data Storage

- Uses ETS tables for in-memory storage
- Separate tables for active queue and completed matches
- Ordered set for efficient rank-based matching
- Protected access for data integrity

### Concurrency Handling

- GenServer manages state and synchronizes operations
- ETS provides atomic operations for queue management
- Phoenix PubSub handles real-time notifications
- Absinthe manages subscription state

## Testing

Run the test suite:
```bash
mix test
```

Tests cover:
- Queue operations
- Match processing
- GraphQL mutations
- Real-time subscriptions
- Concurrent request handling
- Edge cases and validation

## Performance Considerations

- Efficient rank-based matching using ETS ordered sets
- Minimal data copying through ETS direct access
- Non-blocking subscription notifications
- Configurable matching windows for performance tuning

## Configuration

Key configurations (in `lib/queue_of_matchmaking/matchmaking_queue.ex`):
```elixir
# Start looking for matches within ±10 rank
@initial_rank_window 10
# Increment by this amount each expansion
@rank_window_increment 90
# Maximum rank difference to consider
@max_rank_window 500
```

These values control the matchmaking algorithm's behavior:

- `@initial_rank_window`: When looking for a match, the system first tries to find players within ±10 rank points of the searching player. For example, if a player with rank 1500 joins, it initially looks for players between 1490-1510.

- `@rank_window_increment`: If no match is found in the initial window, the search range expands by this amount in both directions. In this case, it expands by 90 points each iteration. So the search would go:
  - First try: 1490-1510 (±10)
  - Second try: 1400-1600 (±100)
  - Third try: 1310-1690 (±190)
  And so on until either a match is found or max_rank_window is reached.

- `@max_rank_window`: The maximum allowed difference between two matched players' ranks. At 500, this means players cannot be matched if their ranks differ by more than 500 points. For example, a 1500-rated player will never match with anyone below 1000 or above 2000, ensuring some level of skill parity in matches.

These values can be adjusted to make the matchmaking more or less strict, or to change how quickly it expands its search. Lower values will create more balanced matches but might increase queue times, while higher values will create matches more quickly but with potentially larger skill gaps.

## Development

To start development:

1. Clone the repository
2. Install dependencies with `mix deps.get`
3. Start Phoenix endpoint with `mix phx.server`
4. Visit `http://localhost:4000/graphiql` for interactive GraphQL explorer

## License

MIT License
Copyright (c) 2024 [Your Name/Organization]
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.