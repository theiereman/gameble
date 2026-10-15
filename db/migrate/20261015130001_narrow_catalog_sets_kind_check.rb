class NarrowCatalogSetsKindCheck < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :catalog_sets,
      "kind = 'publisher' OR kind = 'tome' OR kind = 'best_of_year' OR kind = 'theme' OR kind = 'franchise' " \
      "OR kind = 'studio' OR kind = 'hall_of_fame' OR kind = 'ufo'",
      name: "catalog_sets_kind_check"
    add_check_constraint :catalog_sets,
      "kind = 'theme' OR kind = 'franchise' OR kind = 'studio' OR kind = 'hall_of_fame' OR kind = 'ufo'",
      name: "catalog_sets_kind_check", validate: false
  end
end
