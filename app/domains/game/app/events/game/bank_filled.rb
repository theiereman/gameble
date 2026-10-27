module Game
  # Published when a player's empty bank is filled with its first packs
  # (AD-7, AD-10). Identifiers only: data = { player_id: }, on the player's
  # stream (Game::Operation.stream_name).
  class BankFilled < RubyEventStore::Event
  end
end
