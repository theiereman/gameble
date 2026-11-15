class AddExchangesTabToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :exchanges_tab, :string
    add_check_constraint :game_player_states, "exchanges_tab = 'friends' OR exchanges_tab = 'market'",
      name: "game_player_states_exchanges_tab_check", validate: false
  end
end
