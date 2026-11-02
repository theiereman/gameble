module Catalog
  # Staff save the whole roadmap at once: the draft is the roadmap from now
  # on. A row with a token is updated, a row without is added, a saved row
  # the draft leaves out is deleted, and the draft's order is the saved order.
  class SaveRoadmap < ApplicationOperation
    def call(draft:)
      step require_valid(draft)

      transaction do
        step lock_milestones
        saved = step saved_rows(draft)
        step remove_absent(draft)
        ids = step save_milestones(draft.milestones, saved)
        step announce(ids)
        ids
      end
    end

    private

    def require_valid(draft)
      draft.valid? ? Success() : Failure(:invalid_roadmap)
    end

    def lock_milestones
      RoadmapMilestone.connection.execute("LOCK TABLE #{RoadmapMilestone.quoted_table_name} IN SHARE ROW EXCLUSIVE MODE")
      Success()
    end

    def saved_rows(draft)
      milestones = RoadmapMilestone.where(token: draft.milestones.filter_map(&:token)).index_by(&:token)
      stories = RoadmapStory.where(token: draft.milestones.flat_map { |milestone| milestone.stories.filter_map(&:token) }).index_by(&:token)
      known = draft.milestones.all? do |milestone|
        (milestone.token.nil? || milestones.key?(milestone.token)) && milestone.stories.all? { story_known?(it, milestone, milestones, stories) }
      end
      known ? Success({ milestones:, stories: }) : Failure(:row_not_found)
    end

    def story_known?(story, milestone, milestones, stories)
      return true if story.token.nil?

      stories.key?(story.token) && stories[story.token].milestone_id == milestones[milestone.token]&.id
    end

    def remove_absent(draft)
      kept_milestones = draft.milestones.filter_map(&:token)
      kept_stories = draft.milestones.flat_map { |milestone| milestone.stories.filter_map(&:token) }
      gone = RoadmapMilestone.where.not(token: kept_milestones)
      RoadmapStory.where(milestone_id: gone.select(:id)).or(RoadmapStory.where.not(token: kept_stories)).delete_all
      gone.delete_all
      Success()
    end

    def save_milestones(entries, saved)
      Success(entries.each.with_index(1).map do |entry, position|
        milestone = write(RoadmapMilestone, saved[:milestones][entry.token], entry, position)
        save_stories(milestone, entry.stories, saved[:stories])
        milestone.id
      end)
    end

    def save_stories(milestone, entries, saved)
      entries.each.with_index(1) { |entry, position| write(RoadmapStory, saved[entry.token], entry, position, milestone_id: milestone.id) }
    end

    def write(model, record, entry, position, **owner)
      attributes = entry.attributes.merge(position:, **owner)
      return model.create!(attributes) if record.nil?

      record.update!(attributes)
      record
    end

    def announce(milestone_ids)
      publish(RoadmapSaved.new(data: { milestone_ids: }), stream_name: RoadmapMilestone.stream_name)
    end
  end
end
