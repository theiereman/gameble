class ValidateReactionAndForfeitChecks < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_feed_reactions, name: "game_feed_reactions_kind_check"
    validate_check_constraint :game_duels, name: "game_duels_forfeited_by_check"
  end
end
