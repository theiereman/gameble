module Game
  module Market
    class Notice < ApplicationRecord
      self.table_name = "game_market_notices"

      ORDER_END_KINDS = %w[order_served order_expired order_leads order_beaten].freeze
      KINDS = (%w[outbid won sold unsold lead_voided withdrawn wanted listed_above_order] + ORDER_END_KINDS).freeze
      LISTING_INDEX = :index_game_market_notices_on_player_and_listing_alone
      LISTED_ABOVE_INDEX = :index_game_market_notices_listed_above_order
      ORDER_END_INDEX = :index_game_market_notices_order_end

      belongs_to :player, class_name: "Accounts::Player"
      belongs_to :listing, optional: true
      belongs_to :order, optional: true
      belongs_to :other_player, class_name: "Accounts::Player", optional: true

      scope :listed_above_order, -> { where(kind: "listed_above_order") }

      def self.record_for(event, **attributes)
        record(**attributes, at: event.metadata[:timestamp] || Time.current)
      end

      def self.record(player_id:, kind:, listing_id: nil, order_id: nil, other_player_id: nil, amount: nil, at: Time.current)
        return if Accounts::Player.removed.exists?(id: player_id)

        upsert({ player_id:, listing_id:, order_id:, kind:, other_player_id:, amount:, noticed_at: at }, unique_by: unique_index(kind, order_id))
      end

      def self.unique_index(kind, order_id)
        if order_id.nil? then LISTING_INDEX
        elsif kind == "listed_above_order" then LISTED_ABOVE_INDEX
        else ORDER_END_INDEX
        end
      end
    end
  end
end
