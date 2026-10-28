module Game
  class GrantCardBacksJob < ActiveJob::Base
    queue_as :default

    def self.grant(player, retroactive: false)
      held = CardBackUnlock.where(player_id: player.id).pluck(:back)
      ((EarnedSetBacks.call(player) + EarnedMilestoneBacks.call(player)) - held).map do |back|
        UnlockCardBack.new.call(player:, back:, retroactive:)
      end
    end

    def perform(player_id, retroactive: false)
      player = Accounts::PlayerById.call(player_id)
      return if player.nil? || player.banned? || player.deleted?

      self.class.grant(player, retroactive:)
    end
  end
end
