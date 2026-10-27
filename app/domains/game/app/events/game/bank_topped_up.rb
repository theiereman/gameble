module Game
  # Published when a season's publication brings a player's packs to it
  # (Game::HealBank): `packs` inserted into a bank left short of ten,
  # `redrawn` unopened packs of an earlier season drawn again. Identifiers
  # only: data = { player_id:, packs:, redrawn: }, on the player's stream
  # (Game::Operation.stream_name).
  class BankToppedUp < RubyEventStore::Event
  end
end
