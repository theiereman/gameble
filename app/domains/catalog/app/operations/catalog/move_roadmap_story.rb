module Catalog
  # Staff move a roadmap story one place up or down among its milestone's
  # stories, swapping it with its neighbour; the milestone's stories are
  # numbered 1..n again in their new order, under a FOR UPDATE lock of the
  # milestone.
  #
  # Publishes Catalog::RoadmapChanged (story_moved).
  #
  #   Catalog::MoveRoadmapStory.new.call(story:, direction: "down")
  #   # => Success(story) | Failure(:invalid_direction | :at_edge)
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
