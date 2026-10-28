class AddActiveCardBackToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :active_card_back, :string
  end
end
