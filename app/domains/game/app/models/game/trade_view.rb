module Game
  class TradeView < ApplicationRecord
    self.table_name = "game_trade_views"

    belongs_to :trade, class_name: "Game::Trade"
  end
end
