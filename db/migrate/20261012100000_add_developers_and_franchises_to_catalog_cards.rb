class AddDevelopersAndFranchisesToCatalogCards < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_cards, :developers, :string, array: true, default: [], null: false
    add_column :catalog_cards, :franchises, :string, array: true, default: [], null: false
  end
end
