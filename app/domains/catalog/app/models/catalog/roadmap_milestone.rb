module Catalog
  class RoadmapMilestone < ApplicationRecord
    self.table_name = "catalog_roadmap_milestones"

    STATUSES = %w[done in_progress to_come].freeze

    include RoadmapWording::Localized

    has_secure_token :token, length: 24

    has_many :stories, class_name: "Catalog::RoadmapStory", foreign_key: :milestone_id, inverse_of: :milestone, dependent: nil

    scope :ordered, -> { order(:position, :id) }

    def self.stream_name
      "Catalog::Roadmap"
    end

    def to_param
      token
    end
  end
end
