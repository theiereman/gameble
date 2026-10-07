# The weekly goal's reward (CAP-12, AD-9, story 6.5): one row per player and
# week, unique in the database, pointing at the reward pack it granted, so a
# contributor is rewarded once whatever runs the grant.
class CreateGameGoalRewards < ActiveRecord::Migration[8.1]
  def change
    create_table :game_goal_rewards do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.date :week_start, null: false
      t.references :pack, null: false, foreign_key: { to_table: :game_packs }
      t.timestamps

      t.index [ :player_id, :week_start ], unique: true
      t.index :week_start
    end
  end
end
