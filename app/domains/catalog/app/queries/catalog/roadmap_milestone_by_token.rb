module Catalog
  # Reads one roadmap milestone by its token. Nil when absent; a token that
  # is not a String, or a blank one, costs no query.
  #
  #   Catalog::RoadmapMilestoneByToken.call("3fWq…") # => Catalog::RoadmapMilestone | nil
  module RoadmapMilestoneByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      RoadmapMilestone.find_by(token:)
    end
  end
end
