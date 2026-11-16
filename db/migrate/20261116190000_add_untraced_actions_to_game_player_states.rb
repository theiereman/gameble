class AddUntracedActionsToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :goals_completed, :integer, null: false, default: 0
    add_column :game_player_states, :source_code_opened_at, :datetime
    add_column :game_player_states, :support_opened_at, :datetime
  end
end
