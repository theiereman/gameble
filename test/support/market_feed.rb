require_relative "market_sales"

module MarketFeed
  include MarketSales

  def sale_entry!(buyer, card_season, price, sold_at: Time.current)
    listing = sold!(card_season, price, sold_at:, buyer:)
    Game::FeedEntry.record_sale(listing_id: listing.id, buyer_id: buyer.id, card_season_id: card_season.id, price:, settings: Game::Market::CurrentSettings.call, at: sold_at)
    listing
  end
end
