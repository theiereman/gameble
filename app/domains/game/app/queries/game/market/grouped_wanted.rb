module Game
  module Market
    # The cards a player still wants that are on sale now, from the wanted notices on open listings, a card under one of the player's orders
    # left out: seen until one of those listings was created after the player last read the grouped line.
    module GroupedWanted
      Grouped = Data.define(:count, :card, :newest_at, :seen)

      def self.call(player:, locale: I18n.locale)
        listings = Listing.open_now.where(id: Notice.where(player_id: player.id, kind: "wanted").select(:listing_id))
          .pluck(:card_season_id, :created_at)
        card_ids = Catalog::CardSeason.where(id: listings.map(&:first)).pluck(:id, :card_id).to_h
        counted = (card_ids.values & WantedCardIds.call(player)) - listed_above_card_ids(player)
        shown = listings.select { counted.include?(card_ids[it.first]) }
        return if shown.empty?

        newest_card_season_id, newest_at = shown.max_by(&:last)
        read_at = BellRead.where(player_id: player.id, key: BellRead::GROUPED_WANTED_KEY).pick(:read_at)
        Grouped.new(count: counted.size, card: CardNames.call([ newest_card_season_id ], locale:)[newest_card_season_id]&.title, newest_at:,
          seen: read_at.present? && newest_at <= read_at)
      end

      def self.listed_above_card_ids(player)
        Order.where(id: Notice.listed_above_order.where(player_id: player.id).select(:order_id)).pluck(:card_id)
      end
      private_class_method :listed_above_card_ids
    end
  end
end
