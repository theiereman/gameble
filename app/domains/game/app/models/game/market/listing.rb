module Game
  module Market
    class Listing < ApplicationRecord
      self.table_name = "game_market_listings"

      STATUSES = %w[open sold unsold cancelled withdrawn].freeze

      has_secure_token :token, length: 24

      # No seller: the Archives sell one of their copies, and its price is destroyed.
      belongs_to :seller, class_name: "Accounts::Player", optional: true
      belongs_to :leader, class_name: "Accounts::Player", optional: true

      scope :open_now, -> { where(status: "open") }
      scope :sold, -> { where(status: "sold") }
      scope :due, ->(now) { open_now.where(ends_at: ..now) }
      scope :of_archives, -> { where(seller_id: nil) }
    end
  end
end
