module Game
  module Market
    # The editions the Archives auction this week, drawn at random from their stock: a few Epics and one Legendary. None once the week's
    # auctions are open.
    module ArchiveAuctionPicks
      RARITIES = { epic: 5, legendary: 1 }.freeze

      def self.call(now: Time.current)
        return [] if Listing.of_archives.where(created_at: ArchivePrices.week_start(now)..).exists?

        RARITIES.flat_map do |rarity, count|
          ArchiveStock.joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_archive_stocks.card_season_id")
            .where(catalog_card_seasons: { rarity: Catalog::Rarity::TIERS.key(rarity) }).order(Arel.sql("random()")).limit(count).pluck(:card_season_id)
        end
      end
    end
  end
end
