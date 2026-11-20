module Game
  class ExchangesTabsBackfilled < RubyEventStore::Event
    STREAM = "Game::ExchangesTabs$backfilled"
  end
end
