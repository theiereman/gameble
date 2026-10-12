class ValidateCatalogCardSeasonsReviewCountCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :catalog_card_seasons, name: "catalog_card_seasons_review_count_check"
  end
end
