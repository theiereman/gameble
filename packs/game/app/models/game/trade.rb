module Game
  # A trade between two friends (AD-8): the pair, lower player id first,
  # who proposed and who answers, and its status. Two friends have at most
  # one open trade (a partial unique index). A proposal expires 7 days after
  # it was sent; an open trade past that stays open until the expiry job
  # closes it. Written only through the trade operations of this pack (AD-3).
  class Trade < ApplicationRecord
    self.table_name = "game_trades"

    STATUSES = %w[open cancelled declined accepted expired].freeze
    LIFETIME = 7.days

    has_many :items, class_name: "Game::TradeItem", inverse_of: :trade, dependent: nil

    scope :in_progress, -> { where(status: "open") }

    def open? = status == "open"

    def offer_items = items.select { |item| item.side == "offer" }
    def request_items = items.select { |item| item.side == "request" }
  end
end
