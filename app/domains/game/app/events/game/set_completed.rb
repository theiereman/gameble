module Game
  # Published when a player reaches the complete tier of a set for the first
  # time, once per player and set, by the operation that raised their
  # quantities (an opening, an accepted trade), after its own event.
  # Achievements unlock on it. Identifiers only: data = { player_id:,
  # set_id: }, on the player's stream (Game::Operation.stream_name).
  class SetCompleted < RubyEventStore::Event
  end
end
