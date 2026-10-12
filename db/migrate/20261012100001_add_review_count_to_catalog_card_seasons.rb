class AddReviewCountToCatalogCardSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_card_seasons, :review_count, :integer
    add_check_constraint :catalog_card_seasons, "review_count IS NULL OR review_count >= 1",
      name: "catalog_card_seasons_review_count_check", validate: false
  end
end
