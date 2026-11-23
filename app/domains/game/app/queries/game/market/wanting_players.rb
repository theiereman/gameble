module Game
  module Market
    module WantingPlayers
      def self.call(card_season_id, except: nil)
        card_id, rarity = Catalog::CardSeason.where(id: card_season_id).pick(:card_id, :rarity)
        return [] if card_id.nil?

        Wanted.in_play.counting_at(rarity).where(card_id:).where.not(player_id: except).distinct.order(:player_id).pluck(:player_id)
      end
    end
  end
end
