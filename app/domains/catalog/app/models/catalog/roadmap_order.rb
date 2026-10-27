module Catalog
  module RoadmapOrder
    DIRECTIONS = %w[up down].freeze

    def self.moved(ids, id, direction)
      index = ids.index(id)
      return nil if index.nil?

      neighbour = direction == "up" ? index - 1 : index + 1
      return nil unless neighbour.between?(0, ids.size - 1)

      ids.dup.tap { |order| order[index], order[neighbour] = order[neighbour], order[index] }
    end
  end
end
