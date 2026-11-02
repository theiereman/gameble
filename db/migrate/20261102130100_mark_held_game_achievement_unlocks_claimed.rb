class MarkHeldGameAchievementUnlocksClaimed < ActiveRecord::Migration[8.1]
  def up
    safety_assured { execute "UPDATE game_achievement_unlocks SET claimed_at = unlocked_at WHERE claimed_at IS NULL" }
  end

  def down
  end
end
