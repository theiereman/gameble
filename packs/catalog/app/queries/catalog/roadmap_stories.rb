module Catalog
  # The stories of one roadmap milestone in their order, shown or hidden, for
  # the back-office.
  #
  #   Catalog::RoadmapStories.call(milestone) # => [ Catalog::RoadmapStory, … ]
  module RoadmapStories
    def self.call(milestone)
      RoadmapStory.where(milestone_id: milestone.id).ordered.to_a
    end
  end
end
