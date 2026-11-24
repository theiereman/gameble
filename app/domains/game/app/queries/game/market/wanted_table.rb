module Game
  module Market
    # The wanted table: the set-apart copies still free, one line per edition, best order first, then the most seekers,
    # the highest entrustment value and the ref; a Common or Uncommon line is drawn the orders its copies serve, in that order, each order once,
    # while a line above them only reads the prices of the orders that would back its auction.
    module WantedTable
      Line = Data.define(:card_season_id, :ref, :rarity, :copies, :seekers, :orders, :backing, :price, :value, :minimum, :stamp) do
        def direct? = DirectSale.rarity?(rarity)

        def best_price = direct? ? orders.first&.price : backing.first
      end

      def self.call(player, copies:, settings:, now: Time.current)
        editions = free_editions(player, copies)
        return [] if editions.empty?

        ids = editions.map(&:first)
        counts = WantedCounts.call(editions.map(&:second).uniq, except: player.id)
        best = EligibleOrders.best(ids, except: player.id, now:)
        prices = EditionPrices.call(ids)
        backing = EligibleOrders.prices(ids, except: player.id, now:)
        lines = editions.map do |id, card_id, slug, season_number, tier, free|
          rarity = Catalog::Rarity::TIERS.fetch(tier)
          Line.new(card_season_id: id, ref: EntrustableCopies.ref(slug, season_number), rarity:, copies: [ copies.fetch(id), free ].min,
            seekers: counts[[ card_id, rarity.to_s ]], orders: [], backing: DirectSale.rarity?(rarity) ? [] : backing.fetch(id, []),
            price: prices.fetch(id, EditionPrices::NO_SALE), value: settings.entrustment(rarity), minimum: settings.minimum_price(rarity), stamp: settings.stamp(rarity))
        end
        sorted = lines.sort_by { [ best[it.card_season_id] ? -best[it.card_season_id].price : 1, -it.seekers, -it.value, it.ref ] }
        drawn = EligibleOrders.draw(sorted.map { [ it.card_season_id, it.direct? ? it.copies : 0 ] }, except: player.id, now:)
        sorted.zip(drawn).map { |line, orders| line.with(orders:) }
      end

      def self.free_editions(player, copies)
        wanted = copies.select { |_, count| count.to_i.positive? }
        return [] if wanted.empty?

        Holding.joins(WantedCopies::JOINS).where(player_id: player.id, card_season_id: wanted.keys).where("game_holdings.quantity > game_holdings.reserved")
          .where.not(catalog_card_seasons: { rarity: nil })
          .pluck("catalog_card_seasons.id", "catalog_card_seasons.card_id", "catalog_cards.slug", "catalog_seasons.number", "catalog_card_seasons.rarity",
            Arel.sql("game_holdings.quantity - game_holdings.reserved"))
      end
      private_class_method :free_editions
    end
  end
end
