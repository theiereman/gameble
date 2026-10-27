module Catalog
  # Staff word a roadmap story in both languages, give it a status and show
  # or hide it. Its milestone and its place are kept.
  #
  # Publishes Catalog::RoadmapChanged (story_updated).
  #
  #   Catalog::UpdateRoadmapStory.new.call(story:, wording_fr: "…", wording_en: "…", status: "done", shown: true)
  #   # => Success(story) | Failure(:invalid_wording | :invalid_status)
  class UpdateRoadmapStory < ApplicationOperation
    include RoadmapEditing

    def call(story:, wording_fr:, wording_en:, status:, shown:)
      attributes = step entry_attributes(wording_fr:, wording_en:, status:, shown:)

      transaction do
        story.lock!
        story.update!(attributes)
        step publish_change("story_updated", milestone_id: story.milestone_id, story_id: story.id)
        story
      end
    end
  end
end
