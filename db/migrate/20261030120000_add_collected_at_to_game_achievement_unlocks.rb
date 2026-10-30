class AddCollectedAtToGameAchievementUnlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :game_achievement_unlocks, :collected_at, :datetime
  end
end
