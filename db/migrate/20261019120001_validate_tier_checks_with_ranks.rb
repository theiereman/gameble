class ValidateTierChecksWithRanks < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :catalog_set_tiers, name: "catalog_set_tiers_tier_check"
    validate_check_constraint :game_set_tiers, name: "game_set_tiers_tier_check"
    validate_check_constraint :game_feed_entries, name: "game_feed_entries_tier_check"
  end
end
