module Game
  module Market
    class Notice < ApplicationRecord
      self.table_name = "game_market_notices"

      KINDS = %w[outbid won sold unsold bought_over lead_voided withdrawn].freeze

      belongs_to :player, class_name: "Accounts::Player"
      belongs_to :listing
      belongs_to :other_player, class_name: "Accounts::Player", optional: true

      def self.record(player_id:, listing_id:, kind:, other_player_id: nil, amount: nil, at: Time.current)
        return if Accounts::Player.removed.exists?(id: player_id)

        upsert({ player_id:, listing_id:, kind:, other_player_id:, amount:, noticed_at: at }, unique_by: %i[player_id listing_id])
      end
    end
  end
end
