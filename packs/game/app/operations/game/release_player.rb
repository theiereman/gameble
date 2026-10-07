module Game
  # Releases what a player whose account is being deleted holds (CAP-14,
  # AD-14): under their bank lock, their feed entries (gone from the feed),
  # daily bonus claims, goal rewards, packs (the bank and the opened ones),
  # holdings (their cards), set completions, friend code and game state row
  # (their latest activity and the NOUVEAU watermark) are deleted, in the
  # order the foreign keys ask, the state row last as AD-10's lock order
  # asks. The weekly contributions stay: anonymous counts once the record is
  # anonymised, they keep the community goal's total. Their first
  # discoveries stay too, their pack forgotten, so a card is never
  # discovered twice in its season (story 6.7). Story 5.11 adds the trades,
  # friendships and invitations; meanwhile the trade operations treat a
  # deleted partner as no friend and release nothing of theirs
  # (Game::TradeSteps).
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
        GoalReward.where(player_id: player.id).delete_all
        FirstDiscovery.where(player_id: player.id).update_all(pack_id: nil, updated_at: Time.current)
        Pack.where(player_id: player.id).delete_all
        Holding.where(player_id: player.id).delete_all
        SetCompletion.where(player_id: player.id).delete_all
        FriendCode.where(player_id: player.id).delete_all
        PlayerState.where(player_id: player.id).delete_all
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
