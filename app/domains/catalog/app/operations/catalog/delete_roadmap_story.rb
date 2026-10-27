module Catalog
  class DeleteRoadmapStory < ApplicationOperation
    include RoadmapEditing

    def call(story:)
      transaction do
        step remove(story)
        step publish_change("story_deleted", milestone_id: story.milestone_id, story_id: story.id)
        story
      end
    end

    private

    def remove(story)
      RoadmapStory.where(id: story.id).delete_all.zero? ? Failure(:story_not_found) : Success()
    end
  end
end
