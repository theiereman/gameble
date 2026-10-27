module Catalog
  module LandingRoadmap
    MILESTONE_LIMIT = 6
    STORY_LIMIT = 2

    def self.call(locale:)
      PublicRoadmap.call(locale:).first(MILESTONE_LIMIT).map do |milestone|
        milestone.with(stories: milestone.stories.first(STORY_LIMIT))
      end
    end
  end
end
