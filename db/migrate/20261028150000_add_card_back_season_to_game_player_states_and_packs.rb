class AddCardBackSeasonToGamePlayerStatesAndPacks < ActiveRecord::Migration[8.1]
  def change
    add_column :game_player_states, :active_card_back_season, :integer
    add_column :game_packs, :card_back_season, :integer
  end
end
