module Game
  # One card of one side of a trade, with a chosen quantity (AD-8). The
  # `offer` side is reserved on the proposer's holdings while the trade is
  # open; the `request` side is only checked free at acceptance.
  class TradeItem < ApplicationRecord
    self.table_name = "game_trade_items"

    SIDES = %w[offer request].freeze
    MAX_CARDS_PER_SIDE = 4
    MAX_QUANTITY = 999

    belongs_to :trade, class_name: "Game::Trade", inverse_of: :items
  end
end
