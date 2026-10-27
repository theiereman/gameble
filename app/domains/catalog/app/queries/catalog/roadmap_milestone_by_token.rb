module Catalog
  module RoadmapMilestoneByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      RoadmapMilestone.find_by(token:)
    end
  end
end
