module Catalog
  module PublicRoadmap
    CACHE_LIFETIME = 10.minutes

    Milestone = Data.define(:wording, :status, :stories)
    Story = Data.define(:wording, :status)

    def self.call(locale:)
      Rails.cache.fetch([ "catalog/public_roadmap", locale.to_s ], expires_in: CACHE_LIFETIME) do
        I18n.with_locale(locale) { read }
      end
    end

    def self.read
      milestones = RoadmapMilestone.where(shown: true).ordered.to_a
      stories = RoadmapStory.where(milestone_id: milestones.map(&:id), shown: true).ordered.group_by(&:milestone_id)
      milestones.map do |milestone|
        shown_stories = stories.fetch(milestone.id, []).map { Story.new(wording: it.wording, status: it.status) }
        Milestone.new(wording: milestone.wording, status: milestone.status, stories: shown_stories)
      end
    end

    private_class_method :read
  end
end
