class AllowGoalRewardsWithoutPack < ActiveRecord::Migration[8.1]
  def change
    change_column_null :game_goal_rewards, :pack_id, true
  end
end
