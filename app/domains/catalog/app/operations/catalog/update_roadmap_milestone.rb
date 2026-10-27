module Catalog
  class UpdateRoadmapMilestone < ApplicationOperation
    include RoadmapEditing

    def call(milestone:, wording_fr:, wording_en:, status:, shown:)
      attributes = step entry_attributes(wording_fr:, wording_en:, status:, shown:)

      transaction do
        step lock_milestones
        milestone.lock!
        milestone.update!(attributes)
        step publish_change("milestone_updated", milestone_id: milestone.id)
        milestone
      end
    end
  end
end
