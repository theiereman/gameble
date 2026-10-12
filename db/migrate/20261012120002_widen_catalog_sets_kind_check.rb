# Sets gain the theme, franchise, studio, hall of fame and UFO kinds; the
# retired kinds stay valid until the published season's sets are rebuilt.
# The check is dropped and added again under its name, unvalidated; the next
# migration validates it.
class WidenCatalogSetsKindCheck < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :catalog_sets, "kind = 'publisher' OR kind = 'tome' OR kind = 'best_of_year'",
      name: "catalog_sets_kind_check"
    add_check_constraint :catalog_sets,
      "kind IN ('publisher', 'tome', 'best_of_year', 'theme', 'franchise', 'studio', 'hall_of_fame', 'ufo')",
      name: "catalog_sets_kind_check", validate: false
  end
end
