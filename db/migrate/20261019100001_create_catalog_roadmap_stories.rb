# The stories staff list under a roadmap milestone.
class CreateCatalogRoadmapStories < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_roadmap_stories do |t|
      t.string :token, null: false, index: { unique: true }
      t.references :milestone, null: false, index: true, foreign_key: { to_table: :catalog_roadmap_milestones }
      t.string :wording_fr, null: false
      t.string :wording_en, null: false
      t.string :status, null: false, default: "to_come"
      t.boolean :shown, null: false, default: true
      t.integer :position, null: false
      t.timestamps

      t.check_constraint "status = 'done' OR status = 'in_progress' OR status = 'to_come'", name: "catalog_roadmap_stories_status_check"
    end
  end
end
