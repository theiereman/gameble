class CreateGameAchievementUnlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :game_achievement_unlocks do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.string :achievement, null: false
      t.datetime :unlocked_at, null: false
      t.timestamps
      t.index %i[player_id achievement], unique: true
    end
  end
end
