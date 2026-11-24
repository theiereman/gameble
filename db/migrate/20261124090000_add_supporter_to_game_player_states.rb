class AddSupporterToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :supporter_at, :datetime
  end
end
