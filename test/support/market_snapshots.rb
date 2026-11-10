# Daily snapshots straight into the table, for the tests that read the economy's series.
#
#   snapshot!(3.days.ago.to_date, created: 1_000, destroyed_total: 400, median_daily_earnings: 5_000)
module MarketSnapshots
  def snapshot!(day, **figures)
    Game::Market::DailySnapshot.create!({ day:, created: 0, destroyed_total: 0, forfeited: 0, circulation: 0, reconciliation_balanced: true }.merge(figures))
  end

  def clear_snapshots = Game::Market::DailySnapshot.connection.execute("DELETE FROM game_market_daily_snapshots")
end
