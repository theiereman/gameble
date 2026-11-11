module MarketSales
  def sold!(card_season, price, sold_at: Time.current, seller: accounts_players(:player), buyer: nil, average_after_sale: nil,
    settings: Game::Market::CurrentSettings.call)
    Game::Market::Listing.create!(seller:, leader: buyer, leader_maximum: (price if buyer), card_season_id: card_season.id, settings_id: settings.id,
      starting_price: [ price, 1_300 ].min, current_price: price, duration_hours: 24, ends_at: sold_at, status: "sold", sold_at:, final_price: price, average_after_sale:)
  end
end
