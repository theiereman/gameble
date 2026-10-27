module Catalog
  module RoadmapStories
    def self.call(milestone)
      RoadmapStory.where(milestone_id: milestone.id).ordered.to_a
    end
  end
end
