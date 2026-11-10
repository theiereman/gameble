module MarketSnapshots
  def snapshot!(day, **figures)
    Game::Market::DailySnapshot.create!({ day:, created: 0, destroyed_total: 0, forfeited: 0, circulation: 0, reconciliation_balanced: true }.merge(figures))
  end

  def clear_snapshots = Game::Market::DailySnapshot.connection.execute("DELETE FROM game_market_daily_snapshots")
end
