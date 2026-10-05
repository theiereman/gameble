# No two cards of a season share a number (R3, AD-5); the card-seasons not
# numbered yet (NULL) do not collide. Built concurrently so the table stays
# writable (strong_migrations).
class IndexCatalogCardSeasonsOnSeasonAndNumber < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :catalog_card_seasons, [ :season_id, :number ], unique: true,
      name: "index_catalog_card_seasons_on_season_id_and_number", algorithm: :concurrently
  end
end
