# A player's decks of up to twelve editions, each a game at most once; a deck card keeps its card-season's game beside it so
# the database refuses a second edition of a game in the same deck.
class CreateGameDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :game_decks do |t|
      t.references :player, null: false, index: false, foreign_key: { to_table: :accounts_players }
      t.string :token, null: false, index: { unique: true }
      t.string :name, null: false
      t.timestamps

      t.index "player_id, lower(name)", unique: true, name: "index_game_decks_on_player_id_and_lower_name"
      t.check_constraint "char_length(name) BETWEEN 1 AND 24", name: "game_decks_name_check"
    end

    create_table :game_deck_cards do |t|
      t.references :deck, null: false, index: false, foreign_key: { to_table: :game_decks, on_delete: :cascade }
      t.references :card_season, null: false, index: true, foreign_key: { to_table: :catalog_card_seasons }
      t.references :card, null: false, index: false, foreign_key: { to_table: :catalog_cards }
      t.integer :slot, limit: 2, null: false
      t.timestamps

      t.index %i[deck_id slot], unique: true
      t.index %i[deck_id card_id], unique: true
      t.check_constraint "slot BETWEEN 1 AND 12", name: "game_deck_cards_slot_check"
    end
  end
end
