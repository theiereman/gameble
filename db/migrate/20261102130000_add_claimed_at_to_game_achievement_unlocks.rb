class AddClaimedAtToGameAchievementUnlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :game_achievement_unlocks, :claimed_at, :datetime
  end
end
