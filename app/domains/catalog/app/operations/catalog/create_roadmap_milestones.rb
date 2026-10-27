module Catalog
  class CreateRoadmapMilestones < ApplicationOperation
    include RoadmapEditing

    def call(epics:)
      transaction do
        step lock_milestones
        fresh = step epics_without_milestone(epics)
        milestones = step create(fresh)
        step announce(milestones)
        milestones
      end
    end

    private

    def epics_without_milestone(epics)
      known = RoadmapMilestone.pluck(:epic_slug)
      Success(epics.uniq(&:slug).reject { known.include?(it.slug) })
    end

    def create(epics)
      last = RoadmapMilestone.maximum(:position) || 0
      Success(epics.each.with_index(last + 1).map do |epic, position|
        wording = epic.title.truncate(RoadmapWording::LENGTH)
        RoadmapMilestone.create!(epic_slug: epic.slug, wording_fr: wording, wording_en: wording, status: "to_come", shown: false, position:)
      end)
    end

    def announce(milestones)
      return Success() if milestones.empty?

      publish(RoadmapMilestonesCreated.new(data: { milestone_ids: milestones.map(&:id) }), stream_name: RoadmapMilestone.stream_name)
    end
  end
end
