class AddAllocationSeasonsToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :allocation_received_season, :integer
    add_column :game_player_states, :allocation_seen_season, :integer
  end
end
