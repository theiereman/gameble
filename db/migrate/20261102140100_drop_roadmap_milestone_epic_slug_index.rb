class DropRoadmapMilestoneEpicSlugIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :catalog_roadmap_milestones, :epic_slug, unique: true,
      name: "index_catalog_roadmap_milestones_on_epic_slug", algorithm: :concurrently
  end
end
