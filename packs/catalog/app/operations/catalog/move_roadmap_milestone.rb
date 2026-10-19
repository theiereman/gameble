module Catalog
  # Staff move a roadmap milestone one place up or down, swapping it with its
  # neighbour; the milestones are numbered 1..n again in their new order. The
  # milestones table is locked as the automatic creation locks it, so a
  # milestone created meanwhile lands after the renumbered ones.
  #
  # Publishes Catalog::RoadmapChanged (milestone_moved).
  #
  #   Catalog::MoveRoadmapMilestone.new.call(milestone:, direction: "up")
  #   # => Success(milestone) | Failure(:invalid_direction | :at_edge)
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
