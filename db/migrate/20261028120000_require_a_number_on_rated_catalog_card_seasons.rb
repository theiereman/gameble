class RequireANumberOnRatedCatalogCardSeasons < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :catalog_card_seasons, "rarity IS NULL OR number IS NOT NULL",
      name: "catalog_card_seasons_rarity_requires_number_check", validate: false
  end
end
