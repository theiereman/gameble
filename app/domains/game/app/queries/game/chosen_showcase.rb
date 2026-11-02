module Game
  module ChosenShowcase
    SIZE = ShowcaseEntry::SIZE

    def self.call(player)
      return [] if player.nil?

      ShowcaseEntry.where(player_id: player.id).order(:position, :id).pluck(:card_season_id)
    end

    def self.among(player_ids, limit:)
      return {} if player_ids.empty?

      firsts = ShowcaseEntry.where(player_id: player_ids)
        .select(:player_id, :card_season_id, Arel.sql("ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY position, id) AS place"))
      ShowcaseEntry.from(firsts, :game_showcase_entries).where("place <= ?", limit).order(:player_id, :place)
        .pluck(:player_id, :card_season_id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    end

    def self.full?(card_season_ids) = card_season_ids.size >= SIZE
  end
end
