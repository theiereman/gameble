# Settings versions for the tests that touch the market.
#
#   open_market!                       # a new version in force, open, at the starting values
#   open_market!(entrustment_rare: 60)
#   close_market!                      # a new version in force, closed
#   forget_market!                     # no version at all, as before the first one, with no PiCoins either
module MarketSettings
  def open_market!(**overrides)
    Game::Market::Settings.create!(Game::Market::StartingSettings::ATTRIBUTES.merge(open: true, **overrides))
  end

  def close_market!(**overrides)
    open_market!(open: false, **overrides)
  end

  def forget_market!
    Game::FeedEntry.where.not(order_id: nil).delete_all
    [ Game::Market::LedgerEntry, Game::Market::Order, Game::Market::Wallet, Game::Market::ArchiveWithdrawal, Game::Market::Settings ].each(&:delete_all)
  end
end
