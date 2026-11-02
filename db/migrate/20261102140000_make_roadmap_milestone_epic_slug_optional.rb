# Milestones are no longer generated from epics: the column stays, unused,
# until a later release drops it.
class MakeRoadmapMilestoneEpicSlugOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :catalog_roadmap_milestones, :epic_slug, true
  end
end
