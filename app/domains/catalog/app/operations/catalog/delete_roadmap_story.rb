module Catalog
  # Staff delete a roadmap story. The stories after it keep their places,
  # which stay in order.
  #
  # Publishes Catalog::RoadmapChanged (story_deleted).
  #
  #   Catalog::DeleteRoadmapStory.new.call(story:)
  #   # => Success(story) | Failure(:story_not_found)
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
