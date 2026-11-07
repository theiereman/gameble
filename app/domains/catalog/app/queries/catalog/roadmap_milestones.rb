module Catalog
  module RoadmapMilestones
    # Every milestone and its stories, in order, as an editable draft.
    def self.call
      RoadmapDraft.from_records(RoadmapMilestone.includes(:stories).ordered)
    end
  end
end
