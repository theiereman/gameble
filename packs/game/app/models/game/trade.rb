module Game
  # A trade between two friends (AD-8): the pair, lower player id first,
  # who proposed and who answers, and its status. Two friends have at most
  # one open trade (a partial unique index). A proposal expires 7 days after
  # it was sent or last countered (`proposed_at`, `expires_at`); an open
  # trade past that can no longer be accepted nor countered, and stays open
  # until Game::ExpireTradesJob closes it. A counter-proposal swaps
  # `proposer_id` and `recipient_id`: the recipient is the player whose turn
  # it is. Written only through the trade operations of this pack (AD-3).
  class Trade < ApplicationRecord
    self.table_name = "game_trades"

    STATUSES = %w[open cancelled declined accepted expired].freeze
    LIFETIME = 7.days

    has_many :items, class_name: "Game::TradeItem", inverse_of: :trade, dependent: nil

    scope :in_progress, -> { where(status: "open") }
    # The open trades past their expiry at `now`.
    scope :due, ->(now) { in_progress.where(expires_at: ..now) }

    def open? = status == "open"
    def expired?(now) = expires_at <= now

    def offer_items = items.select { |item| item.side == "offer" }
    def request_items = items.select { |item| item.side == "request" }
  end
end
