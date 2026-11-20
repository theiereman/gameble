module MarketSales
  def sold!(card_season, price, sold_at: Time.current, seller: accounts_players(:player), buyer: nil, average_after_sale: nil,
    settings: Game::Market::CurrentSettings.call)
    Game::Market::Listing.create!(seller:, leader: buyer, leader_maximum: (price if buyer), card_season_id: card_season.id, settings_id: settings.id,
      starting_price: [ price, 13 ].min, current_price: price, duration_hours: 24, ends_at: sold_at, status: "sold", sold_at:, final_price: price, average_after_sale:)
  end

  # A buy order served by a direct sale, straight into the table.
  def served!(card_season, price, served_at: Time.current, seller: accounts_players(:player), buyer: accounts_players(:moderator), average_after_sale: price,
    settings: Game::Market::CurrentSettings.call)
    Game::Market::Order.create!(player: buyer, card_id: card_season.card_id, settings:, price:, expires_at: served_at + 7.days, status: "served",
      seller_id: seller.id, served_card_season_id: card_season.id, served_at:, average_after_sale:)
  end
end
