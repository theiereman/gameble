module Game
  module Market
    module AltSignals
      # A sale at the minimum price of its rarity, in the settings the listing was created under, repeated between the same two accounts.
      module MinimumPriceSales
        MINIMUM = "CASE catalog_card_seasons.rarity #{Catalog::Rarity::TIERS.map { |tier, name| "WHEN #{tier} THEN game_market_settings.minimum_price_#{name}" }.join(" ")} END".freeze

        def self.call(now:)
          pairs = Listing.sold.where(sold_at: (now - MARKET_WINDOW_DAYS.days)..).where.not(leader_id: nil)
            .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_listings.card_season_id")
            .joins("JOIN game_market_settings ON game_market_settings.id = game_market_listings.settings_id")
            .where("game_market_listings.final_price = #{MINIMUM}")
            .group(:seller_id, :leader_id).having("COUNT(*) >= ?", MINIMUM_PRICE_SALES_REQUIRED).count
          pairs.map { |(seller_id, buyer_id), sales| detected(seller_id, buyer_id, sales) }
        end

        def self.detected(seller_id, buyer_id, sales)
          Detected.new(account_id: seller_id, signal: "minimum_price_sales", other_account_id: buyer_id, facts: { "sales" => sales })
        end

        private_class_method :detected
      end
    end
  end
end
