module Catalog
  class MoveRoadmapMilestone < ApplicationOperation
    include RoadmapEditing

    def call(milestone:, direction:)
      step require_direction(direction)

      transaction do
        step lock_milestones
        order = step moved(milestone, direction)
        step renumber(RoadmapMilestone, order, Time.current)
        step publish_change("milestone_moved", milestone_id: milestone.id)
        milestone.reload
      end
    end

    private

    def moved(milestone, direction)
      order = RoadmapOrder.moved(RoadmapMilestone.ordered.ids, milestone.id, direction)
      order ? Success(order) : Failure(:at_edge)
    end
  end
end
