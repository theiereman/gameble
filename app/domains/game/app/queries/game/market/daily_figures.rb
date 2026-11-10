module Game
  module Market
    # What one UTC day of the economy comes to, read from the ledger, the opened packs and the wallets.
    module DailyFigures
      ACTIVE_DAYS = 90
      DESTROYING_KINDS = %w[stamp commission forfeit].freeze
      EARNING_KINDS = %w[mint sale commission].freeze

      Figures = Data.define(:created, :destroyed, :forfeited, :active_players, :median_daily_earnings, :top_share_basis_points)

      def self.of(day)
        from = day.in_time_zone("UTC")
        period = from...(from + 1.day)
        entries = LedgerEntry.where(created_at: period)
        Figures.new(
          created: entries.where(kind: "mint").sum(:available_delta),
          destroyed: -entries.where(kind: DESTROYING_KINDS).sum(:available_delta),
          forfeited: -entries.where(kind: "forfeit").sum(:available_delta),
          active_players: active_players(period.end, ACTIVE_DAYS.days),
          median_daily_earnings: median_daily_earnings(entries, period),
          top_share_basis_points: top_share_basis_points
        )
      end

      def self.active_players(period_end, length) = Pack.where(opened_at: (period_end - length)...period_end).distinct.count(:player_id)

      def self.median_daily_earnings(entries, period)
        active = Pack.where(opened_at: period).select(:player_id)
        earnings = entries.where(kind: EARNING_KINDS, player_id: active).group(:player_id).sum(:available_delta).values
        Median.of(earnings.select(&:positive?))
      end

      # The richest hundredth of the wallets holding PiCoins, as a share of all of them, read as the wallets stand now.
      def self.top_share_basis_points
        holding = Wallet.where("available + committed > 0")
        count, total = holding.pick(Arel.sql("COUNT(*)"), Arel.sql("SUM(available + committed)"))
        return if count.zero?

        top = holding.order(Arel.sql("available + committed DESC")).limit(count.ceildiv(100)).pluck(Arel.sql("available + committed")).sum
        (top * 10_000).div(total.to_i)
      end

      private_class_method :median_daily_earnings, :top_share_basis_points
    end
  end
end
