module Game
  # Published when a player opens a pack (AD-7, AD-10). Identifiers only:
  # data = { player_id:, pack_id: }, on the player's stream
  # (Game::Operation.stream_name).
  class PackOpened < RubyEventStore::Event
  end
end
