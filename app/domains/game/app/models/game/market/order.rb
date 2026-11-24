module Game
  module Market
    # A standing offer to buy one card at a price, priced against the settings version it was placed under.
    class Order < ApplicationRecord
      self.table_name = "game_market_orders"

      STATUSES = %w[open served expired cancelled withdrawn bid beaten].freeze
      RARITY_NAMES = SettingsRules::RARITIES.map(&:to_s).freeze

      has_secure_token :token, length: 24

      belongs_to :player, class_name: "Accounts::Player"
      belongs_to :settings, class_name: "Game::Market::Settings"
      belongs_to :listing, optional: true

      scope :open_at, ->(now) { where(status: "open").where.not(expires_at: ..now) }
      scope :due, ->(now) { where(status: "open", expires_at: ..now) }
      scope :reaching, ->(rarity) do
        raise ArgumentError, "unknown rarity: #{rarity.inspect}" unless RARITY_NAMES.include?(rarity.to_s)

        joins(:settings).where("game_market_settings.minimum_price_#{rarity} <= game_market_orders.price")
      end
    end
  end
end
