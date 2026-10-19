# The landing's roadmap: one milestone per epic of the initiative, created
# hidden by catalog:create_roadmap_milestones and worded by staff.
class CreateCatalogRoadmapMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_roadmap_milestones do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :epic_slug, null: false, index: { unique: true }
      t.string :wording_fr, null: false
      t.string :wording_en, null: false
      t.string :status, null: false, default: "to_come"
      t.boolean :shown, null: false, default: false
      t.integer :position, null: false
      t.timestamps

      t.check_constraint "status = 'done' OR status = 'in_progress' OR status = 'to_come'", name: "catalog_roadmap_milestones_status_check"
    end
  end
end
