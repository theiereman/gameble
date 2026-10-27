module Game
  class TradeItem < ApplicationRecord
    self.table_name = "game_trade_items"

    SIDES = %w[offer request].freeze
    MAX_CARDS_PER_SIDE = 4
    MAX_QUANTITY = 999

    belongs_to :trade, class_name: "Game::Trade", inverse_of: :items
  end
end
