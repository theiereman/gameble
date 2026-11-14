module Game
  module Market
    module WantedNoticePlayers
      Listed = Data.define(:token, :card_season_id, :player_ids)

      def self.call(listing_id) = Notice.where(listing_id:, kind: "wanted").order(:player_id).pluck(:player_id)

      def self.first_in(listing_id, quiet_for:)
        token, card_season_id = Listing.where(id: listing_id).pick(:token, :card_season_id)
        return Listed.new(token: nil, card_season_id: nil, player_ids: []) if token.nil?

        noticed = Notice.where(listing_id:, kind: "wanted")
        recent = Notice.where(kind: "wanted", player_id: noticed.select(:player_id)).where.not(listing_id:)
          .where("game_market_notices.noticed_at > ?", Time.current - quiet_for).select(:player_id)
        Listed.new(token:, card_season_id:, player_ids: noticed.where.not(player_id: recent).order(:player_id).pluck(:player_id))
      end
    end
  end
end
