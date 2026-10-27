module Catalog
  module RoadmapMilestones
    Row = Data.define(:token, :epic_slug, :wording_fr, :wording_en, :status, :shown, :position, :story_count) do
      include RoadmapWording::Localized

      def to_param = token
    end

    def self.call
      story_counts = RoadmapStory.group(:milestone_id).count
      RoadmapMilestone.ordered.map do |milestone|
        Row.new(**milestone.slice(:token, :epic_slug, :wording_fr, :wording_en, :status, :shown, :position).symbolize_keys,
          story_count: story_counts.fetch(milestone.id, 0))
      end
    end
  end
end
