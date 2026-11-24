module Game
  module Market
    module ArchiveCaps
      Standing = Data.define(:cap, :window_days, :left, :next_at) do
        def reached? = left.zero?
      end

      def self.call(player:, settings:, now: Time.current)
        return {} unless player

        bought = bought_since(player, settings, now)
        SettingsRules::CAPPED_RARITIES.index_with { standing(settings, it, bought.fetch(it, []), now) }
      end

      def self.window(settings, rarity) = settings.archive_cap_window_days(rarity).days

      def self.standing(settings, rarity, times, now)
        cap = settings.archive_cap(rarity)
        counted = times.select { it > now - window(settings, rarity) }
        left = [ cap - counted.size, 0 ].max
        next_at = counted[counted.size - cap] + window(settings, rarity) if left.zero?
        Standing.new(cap:, window_days: settings.archive_cap_window_days(rarity), left:, next_at:)
      end

      def self.bought_since(player, settings, now)
        tiers = Catalog::Rarity::TIERS.invert
        conditions = SettingsRules::CAPPED_RARITIES.map do |rarity|
          ArchiveWithdrawal.sanitize_sql_array([ "(catalog_card_seasons.rarity = ? AND game_market_archive_withdrawals.created_at > ?)",
            tiers.fetch(rarity), now - window(settings, rarity) ])
        end
        rows = ArchiveWithdrawal.joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_archive_withdrawals.card_season_id")
          .where(player_id: player.id).where(conditions.join(" OR ")).order(:created_at)
          .pluck(Arel.sql("catalog_card_seasons.rarity"), Arel.sql("game_market_archive_withdrawals.created_at"))
        rows.group_by { |tier, _| Catalog::Rarity::TIERS.fetch(tier) }.transform_values { |pairs| pairs.map(&:last) }
      end

      private_class_method :window, :standing, :bought_since
    end
  end
end
