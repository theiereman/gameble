module Catalog
  module RoadmapEditing
    private

    def entry_attributes(wording_fr:, wording_en:, status:, shown:)
      wordings = { wording_fr: RoadmapWording.clean(wording_fr), wording_en: RoadmapWording.clean(wording_en) }
      return Failure(:invalid_wording) unless wordings.values.all? { RoadmapWording.valid?(it) }
      return Failure(:invalid_status) unless RoadmapMilestone::STATUSES.include?(status)

      Success(wordings.merge(status:, shown: shown == true))
    end

    def lock_milestones
      RoadmapMilestone.connection.execute("LOCK TABLE #{RoadmapMilestone.quoted_table_name} IN SHARE ROW EXCLUSIVE MODE")
      Success()
    end

    def require_direction(direction)
      RoadmapOrder::DIRECTIONS.include?(direction) ? Success(direction) : Failure(:invalid_direction)
    end

    def renumber(records, ids, now)
      ids.each.with_index(1) do |id, position|
        records.where(id:).where.not(position:).update_all(position:, updated_at: now)
      end
      Success()
    end

    def publish_change(change, milestone_id:, story_id: nil)
      publish(RoadmapChanged.new(data: { milestone_id:, story_id:, change: }), stream_name: RoadmapMilestone.stream_name)
    end
  end
end
