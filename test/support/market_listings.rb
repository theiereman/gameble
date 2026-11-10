# Open listings straight into the table: the arrangement of the tests that read the market.
module MarketListings
  def listing!(seller:, card_season:, settings: Game::Market::CurrentSettings.call, starting_price: 1_300, buy_now_price: nil, current_price: nil,
    hours: 24, ends_at: nil, status: "open", created_at: Time.current)
    Game::Market::Listing.create!(seller:, card_season_id: card_season.id, settings_id: settings.id, starting_price:, buy_now_price:,
      current_price: current_price || starting_price, duration_hours: hours, ends_at: ends_at || hours.hours.from_now, status:, created_at:)
  end
end
