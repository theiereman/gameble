module Game
  module ChosenShowcase
    SIZE = ShowcaseEntry::SIZE

    def self.call(player)
      return [] if player.nil?

      ShowcaseEntry.where(player_id: player.id).order(:position, :id).pluck(:card_season_id)
    end

    def self.full?(card_season_ids) = card_season_ids.size >= SIZE
  end
end
