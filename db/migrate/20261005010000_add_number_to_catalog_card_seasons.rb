# A card's number within its season: 1..n over the
# season's n card-seasons, in a random order, given once by
# Catalog::PublishSeason and frozen with the rest of the season data. This is
# the expand step: nullable, as the seasons published before it carry no
# number until `catalog:number_seasons` numbers them; NOT NULL for published
# card-seasons comes once that backfill has run in production.
#
# The check is added without validation and validated in the next migration,
# so adding it does not block the table (strong_migrations).
class AddNumberToCatalogCardSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_card_seasons, :number, :integer
    add_check_constraint :catalog_card_seasons, "number > 0", name: "catalog_card_seasons_number_check", validate: false
  end
end
