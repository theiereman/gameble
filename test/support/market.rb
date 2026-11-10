# Settings versions for the tests that touch the market.
#
#   open_market!                       # a new version in force, open, at the starting values
#   open_market!(entrustment_rare: 6_000)
#   close_market!                      # a new version in force, closed
module MarketSettings
  def open_market!(**overrides)
    Game::Market::Settings.create!(Game::Market::StartingSettings::ATTRIBUTES.merge(open: true, **overrides))
  end

  def close_market!(**overrides)
    open_market!(open: false, **overrides)
  end
end
