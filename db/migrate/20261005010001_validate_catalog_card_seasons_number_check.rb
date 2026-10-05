# Validates the check on a card-season's number added without validation
# (strong_migrations).
class ValidateCatalogCardSeasonsNumberCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :catalog_card_seasons, name: "catalog_card_seasons_number_check"
  end
end
