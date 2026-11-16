class AddDiscordMembershipToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :discord_member_at, :datetime
    add_column :game_player_states, :discord_checked_at, :datetime
  end
end
