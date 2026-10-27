module Game
  class RepostCard < Operation
    HOURLY_LIMIT = 10
    HOURLY_WINDOW = 1.hour
    CARD_COOLDOWN = 24.hours

    def call(player:, card_season_id:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        step held(player, card_season_id)
        step within_hourly_limit(player)
        step not_reposted_recently(player, card_season_id)
        step publish(CardReposted.new(data: { player_id: player.id, card_season_id: }), stream_name: stream_name(player.id))
      end
    end

    private

    def held(player, card_season_id)
      Quantities.call(player, [ card_season_id ]).key?(card_season_id) ? Success() : Failure(:card_not_owned)
    end

    def within_hourly_limit(player)
      recent_reposts(player, HOURLY_WINDOW).count < HOURLY_LIMIT ? Success() : Failure(:repost_limit_reached)
    end

    def not_reposted_recently(player, card_season_id)
      recent_reposts(player, CARD_COOLDOWN).exists?(card_season_id:) ? Failure(:already_reposted) : Success()
    end

    def recent_reposts(player, window)
      FeedEntry.where(kind: "repost", player_id: player.id, occurred_at: window.ago..)
    end
  end
end
