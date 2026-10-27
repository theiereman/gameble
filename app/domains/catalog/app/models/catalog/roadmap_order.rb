module Catalog
  # The order of roadmap milestones, or of one milestone's stories, after one
  # of them moves a place up or down.
  module RoadmapOrder
    DIRECTIONS = %w[up down].freeze

    # `ids` in their current order with `id` swapped with its neighbour in
    # `direction`, or nil when it has no neighbour there (or is not listed).
    #
    #   Catalog::RoadmapOrder.moved([ 4, 7, 9 ], 7, "up") # => [ 7, 4, 9 ]
    def self.moved(ids, id, direction)
      index = ids.index(id)
      return nil if index.nil?

      neighbour = direction == "up" ? index - 1 : index + 1
      return nil unless neighbour.between?(0, ids.size - 1)

      ids.dup.tap { |order| order[index], order[neighbour] = order[neighbour], order[index] }
    end
  end
end
