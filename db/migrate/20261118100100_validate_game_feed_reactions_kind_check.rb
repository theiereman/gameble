class ValidateGameFeedReactionsKindCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_feed_reactions, name: "game_feed_reactions_kind_check"
  end
end
