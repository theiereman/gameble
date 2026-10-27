module Accounts
  # Keeps personal data no longer than the privacy notice says: deletes the
  # accounts idle for Player::IDLE_PERIOD, then erases the reports and the
  # moderation history past their retention. Every step is idempotent, so a
  # late run catches up on the days it missed.
  class ApplyRetentionJob < ActiveJob::Base
    queue_as :default

    IDLE_PLAYER_BATCH_SIZE = 100
    REPORT_BATCH_SIZE = 1000
    MODERATION_PLAYER_BATCH_SIZE = 500

    def perform
      now = Time.current
      accounts = delete_idle_players(now)
      reports = purge_until_empty { PurgeReports.new.call(now:, limit: REPORT_BATCH_SIZE) }
      history = purge_until_empty { PurgeModerationHistory.new.call(now:, limit: MODERATION_PLAYER_BATCH_SIZE) }

      Rails.logger.info("#{self.class.name}: #{accounts} idle accounts deleted, #{reports} reports purged, " \
        "#{history} moderation history rows purged")
    end

    private

    def delete_idle_players(now)
      deleted = 0
      IdlePlayers.call(now:).in_batches(of: IDLE_PLAYER_BATCH_SIZE) do |batch|
        batch.each do |player|
          result = DeleteInactivePlayer.new.call(player:, now:)
          next if result == DeleteInactivePlayer::NO_LONGER_IDLE

          result.value!
          deleted += 1
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
      deleted
    end

    def purge_until_empty
      total = 0
      loop do
        purged = yield.value!
        break if purged.zero?

        total += purged
      end
      total
    end
  end
end
