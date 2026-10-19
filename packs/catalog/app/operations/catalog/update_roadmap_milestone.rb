module Catalog
  # Staff word a roadmap milestone in both languages, give it a status and
  # show or hide it. Its epic and its place are kept. The milestones table is
  # locked first, as the moves lock it, so a save and a move wait in turn.
  #
  # Publishes Catalog::RoadmapChanged (milestone_updated).
  #
  #   Catalog::UpdateRoadmapMilestone.new.call(milestone:, wording_fr: "…", wording_en: "…", status: "in_progress", shown: true)
  #   # => Success(milestone) | Failure(:invalid_wording | :invalid_status)
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
