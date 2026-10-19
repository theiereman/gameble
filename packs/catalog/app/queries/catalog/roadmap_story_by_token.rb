module Catalog
  # Reads one roadmap story by its token, with its milestone. Nil when
  # absent; a token that is not a String, or a blank one, costs no query.
  #
  #   Catalog::RoadmapStoryByToken.call("3fWq…") # => Catalog::RoadmapStory | nil
  module RoadmapStoryByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      RoadmapStory.includes(:milestone).find_by(token:)
    end
  end
end
