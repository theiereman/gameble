module Game
  # A player's game state (AD-10, AD-28): one row per player, unique in the
  # database. It holds nothing yet; later stories add their columns to it.
  # In a transaction it is locked last: the bank lock (Game::BankLock), then
  # holdings, then these rows.
  #
  # Written only through Game::CreatePlayerState (AD-3).
  class PlayerState < ApplicationRecord
    self.table_name = "game_player_states"
  end
end
