# What a later screen needs to name a set (CAP-6, story 2.7): the publisher's
# name, a tome's genre, volume and volume count, a best-of's year. Set names
# are rendered by the collection epic, not stored.
class AddParamsToCatalogSets < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_sets, :params, :jsonb, null: false, default: {}
  end
end
