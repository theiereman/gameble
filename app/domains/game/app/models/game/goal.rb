module Game
  class Goal < ApplicationRecord
    self.table_name = "game_goals"

    POSITIONS = (1..5)

    belongs_to :custom_set, class_name: "Game::CustomSet", optional: true

    def self.drop_reached(player_ids)
      players = Accounts::Player.where(id: where(player_id: player_ids).select(:player_id))
      reached = players.flat_map { |player| GoalNeeds.call(player).select(&:complete?).map(&:goal_id) }
      where(id: reached).delete_all if reached.any?
    end

    def self.drop_unpublished(season_id)
      published = Catalog::Set.where(season_id:).where("catalog_sets.kind = game_goals.set_kind AND catalog_sets.key = game_goals.set_key")
      where.not(set_kind: nil).where(published.arel.exists.not).delete_all
    end
  end
end
