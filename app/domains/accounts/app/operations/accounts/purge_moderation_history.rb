module Accounts
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
