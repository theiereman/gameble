module Catalog
  class UpdateRoadmapStory < ApplicationOperation
    include RoadmapEditing

    def call(story:, wording_fr:, wording_en:, status:, shown:)
      attributes = step entry_attributes(wording_fr:, wording_en:, status:, shown:)

      transaction do
        story.lock!
        story.update!(attributes)
        step publish_change("story_updated", milestone_id: story.milestone_id, story_id: story.id)
        story
      end
    end
  end
end
