module Game
  module CardBacksEarnedIn
    Earned = Data.define(:back, :unlocked_at)

    def self.call(player, season, before:)
      unlocks = CardBackUnlock.where(player_id: player.id)
      unlocks = unlocks.where(unlocked_at: season.published_at..) if season&.published_at
      unlocks = unlocks.where(unlocked_at: ...before) if before
      unlocks.order(:unlocked_at, :id).pluck(:back, :unlocked_at).filter_map do |key, unlocked_at|
        back = CardBacks.find(key)
        Earned.new(back:, unlocked_at:) if back
      end
    end
  end
end
