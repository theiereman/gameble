module Catalog
  # The roadmap module of the landing: the first shown milestones of the
  # roadmap page, each with its first shown stories. Read through the page's
  # cached roadmap, so a stale roadmap is accepted here too.
  #
  #   Catalog::LandingRoadmap.call(locale: :fr) # => [ Catalog::PublicRoadmap::Milestone, … ]
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
