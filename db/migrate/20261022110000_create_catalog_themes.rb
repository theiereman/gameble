# The themes a card can belong to, named in both languages and kept by the
# administrators, and the classification of each Steam tag: attached to a
# theme, or not a theme. A tag is identified by its parameterized key.
class CreateCatalogThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_themes do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :key, null: false, index: { unique: true }
      t.string :name_en, null: false
      t.string :name_fr, null: false
      t.timestamps
    end

    create_table :catalog_tag_classifications do |t|
      t.string :tag_key, null: false, index: { unique: true }
      t.references :theme, foreign_key: { to_table: :catalog_themes }
      t.boolean :not_a_theme, null: false, default: false
      t.timestamps

      t.check_constraint "(theme_id IS NULL) = not_a_theme", name: "catalog_tag_classifications_one_state_check"
    end
  end
end
