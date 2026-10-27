module Game
  # Published when a player collects the daily bonus (CAP-16, AD-10).
  # Identifiers only: data = { player_id:, pack_id: }, on the player's stream
  # (Game::Operation.stream_name).
  class DailyBonusCollected < RubyEventStore::Event
  end
end
