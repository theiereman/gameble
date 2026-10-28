class ValidateCatalogCardSeasonsRarityRequiresNumberCheck < ActiveRecord::Migration[8.1]
  def up
    unnumbered = select_value("SELECT COUNT(*) FROM catalog_card_seasons WHERE rarity IS NOT NULL AND number IS NULL").to_i
    raise "#{unnumbered} published card-seasons have no number: run bin/rails catalog:number_seasons, then migrate again" if unnumbered.positive?

    validate_check_constraint :catalog_card_seasons, name: "catalog_card_seasons_rarity_requires_number_check"
  end

  def down; end
end
