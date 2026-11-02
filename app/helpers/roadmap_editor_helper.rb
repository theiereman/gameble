module RoadmapEditorHelper
  MILESTONE_KEY = "__milestone__".freeze
  STORY_KEY = "__story__".freeze

  def roadmap_status_options
    Catalog::RoadmapMilestone::STATUSES.map { [ t("back_office.roadmaps.statuses.#{it}"), it ] }
  end

  def blank_roadmap_entry(key)
    Catalog::RoadmapDraft.blank_entry(key)
  end
end
