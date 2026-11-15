class ValidateGamePlayerStatesExchangesTab < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :game_player_states, name: "game_player_states_exchanges_tab_check"
  end
end
