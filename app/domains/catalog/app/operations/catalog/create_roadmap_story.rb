module Catalog
  # Staff add a story under a roadmap milestone, after its last story. The
  # milestone is locked FOR UPDATE, so two stories added at once take two
  # places.
  #
  # Publishes Catalog::RoadmapChanged (story_created).
  #
  #   Catalog::CreateRoadmapStory.new.call(milestone:, wording_fr: "…", wording_en: "…", status: "to_come", shown: true)
  #   # => Success(story) | Failure(:invalid_wording | :invalid_status)
  class CreateRoadmapStory < ApplicationOperation
    include RoadmapEditing

    def call(milestone:, wording_fr:, wording_en:, status:, shown:)
      attributes = step entry_attributes(wording_fr:, wording_en:, status:, shown:)

      transaction do
        milestone.lock!
        position = (RoadmapStory.where(milestone_id: milestone.id).maximum(:position) || 0) + 1
        story = RoadmapStory.create!(attributes.merge(milestone:, position:))
        step publish_change("story_created", milestone_id: milestone.id, story_id: story.id)
        story
      end
    end
  end
end
