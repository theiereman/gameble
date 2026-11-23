module Game
  module Market
    # A card a player wants, by a goal missing it or by an open order reaching the rarities it lists. Only RefreshWanted writes it.
    class Wanted < ApplicationRecord
      self.table_name = "game_market_wanted"

      REASONS = %w[goal order].freeze

      belongs_to :player, class_name: "Accounts::Player"
      belongs_to :card, class_name: "Catalog::Card"

      scope :in_play, -> { where.not(player_id: Accounts::Player.removed.select(:id)) }
      scope :counting_at, ->(rarity_name) do
        tier = Catalog::Rarity::TIERS.key(rarity_name&.to_sym)
        tier ? where("game_market_wanted.reason = 'goal' OR ? = ANY(game_market_wanted.rarities)", tier) : where(reason: "goal")
      end
    end
  end
end
