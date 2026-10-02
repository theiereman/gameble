module Game
  # Published when a bank left short by an earlier build is topped back up
  # outside an opening (Game::HealBank, AD-10). Identifiers only:
  # data = { player_id:, packs: }, on the player's stream
  # (Game::Operation.stream_name).
  class BankToppedUp < RubyEventStore::Event
  end
end
