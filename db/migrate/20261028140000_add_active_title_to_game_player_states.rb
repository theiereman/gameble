class AddActiveTitleToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :active_title_kind, :string
    add_column :game_player_states, :active_title_key, :string
    add_column :game_player_states, :active_title_rank, :string
    add_check_constraint :game_player_states,
      "(active_title_kind IS NULL) = (active_title_key IS NULL) AND (active_title_key IS NULL) = (active_title_rank IS NULL)",
      name: "game_player_states_active_title_whole_check", validate: false
  end
end
