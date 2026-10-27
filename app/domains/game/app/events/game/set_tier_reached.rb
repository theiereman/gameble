module Game
  # Published when a player reaches a tier of a set other than complete
  # for the first time, once per player, set and tier, by the operation that
  # raised their quantities (an opening, an accepted trade), after its own
  # event. Reaching a set's complete tier publishes Game::SetCompleted
  # instead. Identifiers only: data = { player_id:, set_id:, tier: }, on the
  # player's stream (Game::Operation.stream_name).
  class SetTierReached < RubyEventStore::Event
  end
end
