module Game
  class PublishWeeklyVerdict < Operation
    def call(player:, week_start:)
      player = step require_player(player)

      transaction do
        step not_yet_published(week_start)
        step publish(WeeklyVerdictReached.new(data: { player_id: player.id, week_start: week_start.iso8601 }), stream_name: stream_name(player.id))
      end
    end

    private

    def not_yet_published(week_start)
      FeedEntry.verdict_of?(week_start) ? Failure(:already_published) : Success()
    end
  end
end
