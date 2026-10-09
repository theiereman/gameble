class AddPrestigeScoreVersionToCatalogCardSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_card_seasons, :prestige_score_version, :integer, limit: 2
  end
end
