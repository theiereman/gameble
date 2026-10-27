module Catalog
  class MoveRoadmapStory < ApplicationOperation
    include RoadmapEditing

    def call(story:, direction:)
      step require_direction(direction)

      transaction do
        RoadmapMilestone.lock("FOR UPDATE").find(story.milestone_id)
        stories = RoadmapStory.where(milestone_id: story.milestone_id)
        order = step moved(stories, story, direction)
        step renumber(stories, order, Time.current)
        step publish_change("story_moved", milestone_id: story.milestone_id, story_id: story.id)
        story.reload
      end
    end

    private

    def moved(stories, story, direction)
      order = RoadmapOrder.moved(stories.ordered.ids, story.id, direction)
      order ? Success(order) : Failure(:at_edge)
    end
  end
end
