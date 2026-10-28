module Game
  class RecordPlayerActivity < ApplicationOperation
    def call(player_id:, activity:, at:)
      PlayerState.upsert(
        { player_id:, last_activity: activity.to_s, last_activity_at: at, created_at: at, updated_at: at, **PlayerState.markers_at_published_season },
        unique_by: :player_id, record_timestamps: false,
        on_duplicate: Arel.sql("last_activity = excluded.last_activity, last_activity_at = excluded.last_activity_at, " \
          "updated_at = excluded.updated_at")
      )
    end
  end
end
