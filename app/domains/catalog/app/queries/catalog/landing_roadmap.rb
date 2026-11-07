module Catalog
  module LandingRoadmap
    MILESTONE_LIMIT = 6
    STORY_LIMIT = 2

    def self.call(locale:)
      limited(PublicRoadmap.call(locale:))
    end

    # What the landing would show of a draft that is not saved yet.
    def self.preview(draft, locale:)
      limited(PublicRoadmap.shown(draft.milestones, locale:))
    end

    def self.limited(milestones)
      milestones.first(MILESTONE_LIMIT).map do |milestone|
        milestone.with(stories: milestone.stories.first(STORY_LIMIT))
      end
    end

    private_class_method :limited
  end
end
