module Catalog
  # A story staff list under a roadmap milestone, worded in both languages,
  # with its own status, visibility and place among the milestone's stories.
  class RoadmapStory < ApplicationRecord
    self.table_name = "catalog_roadmap_stories"

    STATUSES = RoadmapMilestone::STATUSES

    include RoadmapWording::Localized

    has_secure_token :token, length: 24

    belongs_to :milestone, class_name: "Catalog::RoadmapMilestone", inverse_of: :stories

    scope :ordered, -> { order(:position, :id) }

    def to_param
      token
    end
  end
end
