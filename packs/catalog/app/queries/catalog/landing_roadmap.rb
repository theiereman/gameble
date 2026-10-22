module Catalog
  # The roadmap module of the landing: the milestones staff chose to show, in
  # their order, each with its first shown stories, worded in the locale.
  # Cached per locale: a stale roadmap is accepted.
  #
  #   Catalog::LandingRoadmap.call(locale: :fr) # => [ Catalog::LandingRoadmap::Milestone, … ]
  module LandingRoadmap
    CACHE_LIFETIME = 10.minutes
    MILESTONE_LIMIT = 6
    STORY_LIMIT = 2

    Milestone = Data.define(:wording, :status, :stories)
    Story = Data.define(:wording, :status)

    def self.call(locale:)
      Rails.cache.fetch([ "catalog/landing_roadmap", locale.to_s ], expires_in: CACHE_LIFETIME) do
        I18n.with_locale(locale) { read }
      end
    end

    def self.read
      milestones = RoadmapMilestone.where(shown: true).ordered.limit(MILESTONE_LIMIT).to_a
      stories = RoadmapStory.where(milestone_id: milestones.map(&:id), shown: true).ordered.group_by(&:milestone_id)
      milestones.map do |milestone|
        shown_stories = stories.fetch(milestone.id, []).first(STORY_LIMIT).map { Story.new(wording: it.wording, status: it.status) }
        Milestone.new(wording: milestone.wording, status: milestone.status, stories: shown_stories)
      end
    end

    private_class_method :read
  end
end
