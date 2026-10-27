# First discoveries: the first player to
# pull a card in a season, one row per card-season, unique in the database.
# Written by Game::OpenPack in the opening's transaction, `ON CONFLICT DO
# NOTHING`, so two simultaneous openings record it once. The pack is
# forgotten (null) when its player's account is deleted (Game::ReleasePlayer
# deletes the packs); the discovery stays, so the card is never discovered
# twice in its season.
class CreateGameFirstDiscoveries < ActiveRecord::Migration[8.1]
  def change
    create_table :game_first_discoveries do |t|
      t.bigint :card_season_id, null: false
      t.references :player, null: false, foreign_key: { to_table: :accounts_players }
      t.references :pack, foreign_key: { to_table: :game_packs }
      t.datetime :discovered_at, null: false
      t.timestamps
      t.index :card_season_id, unique: true
    end
  end
end
