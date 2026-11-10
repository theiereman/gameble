module Game
  module Market
    # What a player has minted since 00:00 UTC, read from the ledger so the daily cap renews with the day and needs no counter.
    module MintedToday
      def self.call(player_id, now: Time.current)
        day_start = now.utc.beginning_of_day
        LedgerEntry.where(player_id:, kind: "mint", created_at: day_start...(day_start + 1.day)).sum(:available_delta)
      end
    end
  end
end
