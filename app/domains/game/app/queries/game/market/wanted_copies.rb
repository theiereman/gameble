module Game
  module Market
    # A player's free copies other players want, one per edition, with how many want it and the best order it can serve,
    # the most sought first, then the best order, then by ref.
    module WantedCopies
      Copy = Data.define(:card_season_id, :card_id, :ref, :rarity, :seekers, :order)

      JOINS = <<~SQL.squish.freeze
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
        JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
      SQL

      def self.call(player, card_id: nil, now: Time.current)
        return [] if player.nil?

        editions = free_editions(player, card_id)
        counts = WantedCounts.call(editions.map(&:second).uniq, except: player.id)
        sought = editions.filter_map do |id, edition_card_id, slug, season_number, tier|
          rarity = Catalog::Rarity::TIERS.fetch(tier)
          seekers = counts[[ edition_card_id, rarity.to_s ]]
          [ id, edition_card_id, EntrustableCopies.ref(slug, season_number), rarity, seekers ] if seekers.positive?
        end
        orders = EligibleOrders.best(sought.map(&:first), except: player.id, now:)
        sought.map { |id, *rest| Copy.new(id, *rest, orders[id]) }.sort_by { [ -it.seekers, -(it.order&.price || 0), it.ref ] }
      end

      def self.free_editions(player, card_id)
        editions = Holding.joins(JOINS).where(player_id: player.id).where("game_holdings.quantity > game_holdings.reserved")
          .where.not(catalog_card_seasons: { rarity: nil }).where(catalog_card_seasons: { card_id: Wanted.select(:card_id) })
        editions = editions.where(catalog_card_seasons: { card_id: }) if card_id
        editions.pluck("catalog_card_seasons.id", "catalog_card_seasons.card_id", "catalog_cards.slug", "catalog_seasons.number",
          "catalog_card_seasons.rarity")
      end
      private_class_method :free_editions
    end
  end
end
