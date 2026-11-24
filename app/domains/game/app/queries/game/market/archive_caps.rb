module Game
  module Market
    # A player buys at most a few Archive cards a week, whatever their rarity; the count starts again on Monday 00:00 UTC.
    module ArchiveCaps
      WEEKLY_PURCHASES = 5

      Standing = Data.define(:cap, :left, :next_at) do
        def reached? = left.zero?
      end

      # The player's standing under every listed rarity, the same for all; none for a visitor.
      def self.call(player:, settings: nil, now: Time.current)
        return {} unless player

        week = ArchivePrices.week_start(now)
        left = [ WEEKLY_PURCHASES - ArchiveWithdrawal.where(player_id: player.id, created_at: week..).count, 0 ].max
        standing = Standing.new(cap: WEEKLY_PURCHASES, left:, next_at: week + 1.week)
        ArchiveOffers::LISTED.index_with { standing }
      end
    end
  end
end
