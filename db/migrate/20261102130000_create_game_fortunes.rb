# A player's luck at opening packs: what their cards scored against what the
# packs promise, summed once for all time (no week_start) and once per week.
class CreateGameFortunes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_fortunes do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.date :week_start
      t.integer :regular_packs, null: false, default: 0
      t.integer :bonus_packs, null: false, default: 0
      t.integer :reward_packs, null: false, default: 0
      t.integer :common_cards, null: false, default: 0
      t.integer :uncommon_cards, null: false, default: 0
      t.integer :rare_cards, null: false, default: 0
      t.integer :epic_cards, null: false, default: 0
      t.integer :legendary_cards, null: false, default: 0
      t.integer :actual_points, null: false, default: 0
      t.float :expected_points, null: false, default: 0
      t.float :variance, null: false, default: 0
      t.virtual :z_score, type: :float, stored: true,
        as: "CASE WHEN variance > 0 THEN (actual_points - expected_points) / sqrt(variance) ELSE 0 END"
      t.timestamps

      t.index %i[player_id week_start], unique: true, nulls_not_distinct: true
      t.index %i[week_start z_score player_id], order: { z_score: :desc }
      t.check_constraint "regular_packs >= 0 AND bonus_packs >= 0 AND reward_packs >= 0", name: "game_fortunes_packs_check"
      t.check_constraint "variance >= 0", name: "game_fortunes_variance_check"
      t.check_constraint "week_start IS NULL OR extract(isodow FROM week_start) = 1", name: "game_fortunes_week_start_monday_check"
    end
  end
end
