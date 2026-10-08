module Game
  # Published when a player holds every card of a set for the first time,
  # once per player and set (AD-10, story 6.7), by the operation that raised
  # their quantities (an opening, an accepted trade), after its own event.
  # Card backs (epic 9) and achievements unlock on it. Identifiers only:
  # data = { player_id:, set_id: }, on the player's stream
  # (Game::Operation.stream_name).
  class SetCompleted < RubyEventStore::Event
  end
end
