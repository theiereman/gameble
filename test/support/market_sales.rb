# Sold listings straight into the table: the arrangement of the tests that read an edition's sales.
#
#   sold!(card_season, 15_000, sold_at: 2.days.ago)
module MarketSales
  def sold!(card_season, price, sold_at: Time.current, seller: accounts_players(:player), settings: Game::Market::CurrentSettings.call)
    Game::Market::Listing.create!(seller:, card_season_id: card_season.id, settings_id: settings.id, starting_price: 1_300, current_price: price,
      duration_hours: 24, ends_at: sold_at, status: "sold", sold_at:, final_price: price)
  end
end
