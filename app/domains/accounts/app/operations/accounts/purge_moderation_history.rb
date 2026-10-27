module Accounts
  # Erases the moderation history rows that ended more than RETENTION ago,
  # for up to `limit` players at a time. Every row of a deleted account ends
  # at its deletion; a ban ends at the first unban that follows it, or, lifted
  # by hand with no unban, at the player's last update, and never while it is
  # in force; an unban or a dismissal ends when made. All of a
  # player's expired rows go in one statement, so a ban never outlives the
  # unban that ended it. Housekeeping: no event names the rows it erases.
  #
  #   Accounts::PurgeModerationHistory.new.call(now: Time.current, limit: 500) # => Success(count)
  class PurgeModerationHistory < ApplicationOperation
    RETENTION = 1.year

    LATER_UNBAN = <<~SQL.squish
      SELECT 1 FROM accounts_moderation_actions lifting
      WHERE lifting.player_id = accounts_moderation_actions.player_id
        AND lifting.kind = 'unban'
        AND (lifting.created_at, lifting.id) > (accounts_moderation_actions.created_at, accounts_moderation_actions.id)
    SQL

    ENDED_BEFORE_CUTOFF = <<~SQL.squish
      CASE
        WHEN accounts_players.deleted_at IS NOT NULL THEN accounts_players.deleted_at < :cutoff
        WHEN accounts_moderation_actions.kind <> 'ban' THEN accounts_moderation_actions.created_at < :cutoff
        WHEN EXISTS (#{LATER_UNBAN}) THEN EXISTS (#{LATER_UNBAN} AND lifting.created_at < :cutoff)
        ELSE accounts_players.banned_at IS NULL
          AND GREATEST(accounts_moderation_actions.created_at, accounts_players.updated_at) < :cutoff
      END
    SQL

    def call(now:, limit:)
      transaction do
        expired = ModerationAction.joins(:player).where(ENDED_BEFORE_CUTOFF, cutoff: now - RETENTION)
        players = expired.distinct.order(:player_id).limit(limit).select(:player_id)
        ModerationAction.where(id: expired.where(player_id: players).select(:id)).delete_all
      end
    end
  end
end
