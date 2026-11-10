module Game
  module Market
    class Bid < ApplicationRecord
      self.table_name = "game_market_bids"

      OUTCOMES = %w[leading outbid beaten raise won lost voided].freeze

      belongs_to :listing
      belongs_to :player, class_name: "Accounts::Player"

      scope :history_visible, -> { where.not(outcome: "raise") }
      scope :public_outcomes, -> { where.not(outcome: %w[raise voided]) }

      def self.displace(listing_id:, player_id:)
        where(listing_id:, player_id:, outcome: "leading").update_all(outcome: "outbid")
      end

      def self.close_out(listing_id:, winner_id:)
        own = where(listing_id:)
        own.where(player_id: winner_id, outcome: "leading").update_all(outcome: "won")
        own.where.not(player_id: winner_id).where(outcome: %w[leading outbid beaten]).update_all(outcome: "lost")
      end
    end
  end
end
