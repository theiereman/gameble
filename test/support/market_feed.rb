module MarketFeed
  def sale_entry!(buyer, card_season, price, sold_at: Time.current)
    listing = Game::Market::Listing.create!(seller: accounts_players(:player), card_season_id: card_season.id, settings_id: Game::Market::CurrentSettings.call.id,
      starting_price: 1_300, current_price: price, duration_hours: 24, ends_at: sold_at, status: "sold", sold_at:, final_price: price, leader: buyer, leader_maximum: price)
    Game::FeedEntry.record_sale(listing_id: listing.id, buyer_id: buyer.id, card_season_id: card_season.id, price:, settings: Game::Market::CurrentSettings.call, at: sold_at)
    listing
  end
end
