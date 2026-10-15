module Game
  class ReleasePlayer < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        step DropFriendsAndTrades.new.call(player:)
        BankLock.acquire(player.id)
        FeedEntry.where(player_id: player.id).or(FeedEntry.where(partner_id: player.id)).delete_all
        DailyBonusClaim.where(player_id: player.id).delete_all
        GoalReward.where(player_id: player.id).delete_all
        FirstDiscovery.where(player_id: player.id).update_all(pack_id: nil, updated_at: Time.current)
        SetTier.where(player_id: player.id).delete_all
        Pack.where(player_id: player.id).delete_all
        Holding.where(player_id: player.id).delete_all
        SetCompletion.where(player_id: player.id).delete_all
        AchievementUnlock.where(player_id: player.id).delete_all
        FriendCode.where(player_id: player.id).delete_all
        PlayerState.where(player_id: player.id).delete_all
        player
      end
    end
  end
end
