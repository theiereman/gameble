module Game
  class Trade < ApplicationRecord
    self.table_name = "game_trades"

    has_secure_token :token, length: 24

    STATUSES = %w[open cancelled declined accepted expired].freeze
    LIFETIME = 7.days

    has_many :items, class_name: "Game::TradeItem", inverse_of: :trade, dependent: nil

    scope :in_progress, -> { where(status: "open") }
    scope :due, ->(now) { in_progress.where(expires_at: ..now) }

    def open? = status == "open"
    def expired?(now) = expires_at <= now
    def revision = proposed_at.utc.iso8601(6)

    def offer_items = items.select { |item| item.side == "offer" }
    def request_items = items.select { |item| item.side == "request" }
  end
end
