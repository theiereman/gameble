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

    # The shown rows of draft entries, as the public roadmap lists them.
    def self.shown(entries, locale:)
      wording = locale.to_s == "fr" ? :wording_fr : :wording_en
      entries.select(&:shown).map do |milestone|
        stories = milestone.stories.select(&:shown).map { Story.new(wording: it.public_send(wording).to_s, status: status_of(it)) }
        Milestone.new(wording: milestone.public_send(wording).to_s, status: status_of(milestone), stories:)
      end
    end

    def self.status_of(entry)
      RoadmapMilestone::STATUSES.include?(entry.status) ? entry.status : RoadmapDraft::DEFAULT_STATUS
    end

    def self.read
      milestones = RoadmapMilestone.where(shown: true).ordered.to_a
      stories = RoadmapStory.where(milestone_id: milestones.map(&:id), shown: true).ordered.group_by(&:milestone_id)
      milestones.map do |milestone|
        shown_stories = stories.fetch(milestone.id, []).map { Story.new(wording: it.wording, status: it.status) }
        Milestone.new(wording: milestone.wording, status: milestone.status, stories: shown_stories)
      end
    end

    private_class_method :read, :status_of
  end
end
