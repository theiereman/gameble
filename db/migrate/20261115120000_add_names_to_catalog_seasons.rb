class AddNamesToCatalogSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_seasons, :name_en, :string
    add_column :catalog_seasons, :name_fr, :string
  end
end
