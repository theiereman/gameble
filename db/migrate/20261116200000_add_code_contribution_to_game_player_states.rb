class AddCodeContributionToGamePlayerStates < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :code_contribution_at, :datetime
  end
end
