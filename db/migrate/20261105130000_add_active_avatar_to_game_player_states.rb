class AddActiveAvatarToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :active_avatar, :string
  end
end
