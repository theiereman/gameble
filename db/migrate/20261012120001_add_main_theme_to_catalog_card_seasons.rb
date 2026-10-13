class AddMainThemeToCatalogCardSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_card_seasons, :main_theme, :string
  end
end
