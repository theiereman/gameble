module Game
  # Releases what a player whose account is being deleted holds (CAP-14,
  # AD-14): under their bank lock, their feed entries (gone from the feed),
  # daily bonus claims, packs (the bank and the opened ones), holdings (their
  # cards) and friend code are deleted, in the order the foreign keys ask.
  # What names no one once the record is anonymised stays: the weekly
  # contributions (counted in the community goal) and the game state row.
  # Story 5.11 adds the trades, friendships and invitations.
  #
  # Run only by Game::Handlers::PlayerDeleted, inside Accounts::DeletePlayer's
  # transaction and before the record is anonymised, so it publishes nothing
  # (AD-10) and takes the bank lock before the deletion locks the player row
  # for its update (AD-10's lock order). Every bank operation re-checks the
  # deletion once it holds that lock (Game::Operation#lock_bank): an opening
  # that commits first has its rows deleted here, one that waits writes
  # nothing.
  #
  #   Game::ReleasePlayer.new.call(player:)
  #   # => Success(player) | Failure(:player_required)
  class ReleasePlayer < Operation
    def call(player:)
      player = step require_record(player)

      transaction do
        BankLock.acquire(player.id)
        FeedEntry.where(player_id: player.id).delete_all
        DailyBonusClaim.where(player_id: player.id).delete_all
        Pack.where(player_id: player.id).delete_all
        Holding.where(player_id: player.id).delete_all
        FriendCode.where(player_id: player.id).delete_all
        player
      end
    end

    private

    # Not `require_player`: the record is anonymised after this runs.
    def require_record(player)
      player.is_a?(Accounts::Player) && player.persisted? ? Success(player) : Failure(:player_required)
    end
  end
end
