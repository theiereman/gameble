module Game
  class DuelStatsComputed < RubyEventStore::Event
    STREAM = "Game::DuelStats$computed"
  end
end
