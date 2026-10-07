module Game
  # A player's game state (AD-10, AD-28): one row per player, unique in the
  # database. In a transaction it is locked last: the bank lock
  # (Game::BankLock), then holdings, then these rows.
  #
  # `collection_seen_up_to` is the collection's watermark (AD-26): the latest
  # gain the player has seen on their collection, NULL until they first
  # see a new card. Only ever moved forward, by Game::MarkCollectionSeen.
  #
  # `last_activity` and `last_activity_at` are the player's latest game
  # action, an activity key, and its time (AD-24), read by their friends'
  # presence (Game::FriendsPresence). NULL until they first act.
  #
  # Written only through Game::CreatePlayerState, Game::MarkCollectionSeen
  # and the Game::Handlers::PlayerActivity handler (AD-3, AD-10).
  class PlayerState < ApplicationRecord
    self.table_name = "game_player_states"
  end
end
