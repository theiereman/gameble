class ValidateNarrowedCatalogSetsKindCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :catalog_sets, name: "catalog_sets_kind_check"
  end
end
