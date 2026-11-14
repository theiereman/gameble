module Game
  module Market
    module WantingPlayers
      def self.call(card_season_id, except: nil)
        card_id = Catalog::CardSeason.where(id: card_season_id).pick(:card_id)
        return [] if card_id.nil?

        aiming = (aiming_at_game_sets(card_id) + aiming_at_custom_sets(card_id)).uniq - [ except ]
        return [] if aiming.empty?

        (aiming - holders(aiming, card_id) - Accounts::Player.removed.where(id: aiming).pluck(:id)).sort
      end

      def self.aiming_at_game_sets(card_id)
        season = Catalog::PublishedSeason.call
        return [] if season.nil?

        sets = Catalog::Set.where(season_id: season.id)
          .where(id: Catalog::SetMembership.joins(:card_season).where(catalog_card_seasons: { card_id: }).select(:set_id))
          .pluck(:kind, :key)
        return [] if sets.empty?

        Goal.where(custom_set_id: nil).where([ :set_kind, :set_key ] => sets).distinct.pluck(:player_id)
      end

      def self.aiming_at_custom_sets(card_id)
        Goal.where(custom_set_id: CustomSetGame.where(card_id:).select(:custom_set_id)).distinct.pluck(:player_id)
      end

      def self.holders(player_ids, card_id)
        Holding.joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id")
          .where(player_id: player_ids, catalog_card_seasons: { card_id: }).where("game_holdings.quantity > 0").distinct.pluck(:player_id)
      end

      private_class_method :aiming_at_game_sets, :aiming_at_custom_sets, :holders
    end
  end
end
