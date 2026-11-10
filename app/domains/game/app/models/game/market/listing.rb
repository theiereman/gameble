module Game
  module Market
    # One copy offered at auction. Only ListCard and the later market operations write it.
    class Listing < ApplicationRecord
      self.table_name = "game_market_listings"

      STATUSES = %w[open sold unsold cancelled withdrawn].freeze

      has_secure_token :token, length: 24

      belongs_to :seller, class_name: "Accounts::Player"
      belongs_to :leader, class_name: "Accounts::Player", optional: true

      scope :open_now, -> { where(status: "open") }
      scope :due, ->(now) { open_now.where(ends_at: ..now) }
    end
  end
end
