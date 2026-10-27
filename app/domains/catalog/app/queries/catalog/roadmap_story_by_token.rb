module Catalog
  module RoadmapStoryByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      RoadmapStory.includes(:milestone).find_by(token:)
    end
  end
end
