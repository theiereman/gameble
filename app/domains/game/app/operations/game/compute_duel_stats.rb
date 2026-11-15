module Game
  # Replaces every duel profile at once, under a lock so two computations never overlap: on the first deploy, when a season
  # is published and every Monday.
  class ComputeDuelStats < ApplicationOperation
    LOCK_KEY = 0x4455454C
    BATCH_SIZE = 1_000

    def call(reason:, now: Time.current)
      reason = step known_reason(reason.to_s)

      transaction do
        DuelStat.connection.execute(DuelStat.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(?)", LOCK_KEY ]))
        rows = DuelStatRows.new(DuelMeasures.call, previous: previous_percentiles, reason:, now:).to_a
        DuelStat.delete_all
        rows.each_slice(BATCH_SIZE) { DuelStat.insert_all!(it) }
        step publish(DuelStatsComputed.new(data: { reason: }), stream_name: DuelStatsComputed::STREAM)
        rows.size
      end
    end

    private

    def known_reason(reason)
      DuelStat::REASONS.include?(reason) ? Success(reason) : Failure(:unknown_reason)
    end

    def previous_percentiles
      percentiles = DuelStat::STATS.map { :"#{it}_percentile" }
      weekly = DuelStat::STATS.map { :"#{it}_weekly_percentile" }
      DuelStat.pluck(:card_season_id, *percentiles, *weekly).to_h do |card_season_id, *values|
        current, last_weekly = values.each_slice(DuelStat::STATS.size).map { DuelStat::STATS.zip(it).to_h }
        [ card_season_id, { percentiles: current, weekly: last_weekly } ]
      end
    end
  end
end
