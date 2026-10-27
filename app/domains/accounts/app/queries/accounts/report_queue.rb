module Accounts
  module ReportQueue
    Row = Data.define(:player, :counts, :total, :latest_at)

    def self.players
      latest = Report.unhandled.group(:reported_id).select("reported_id, MAX(created_at) AS latest_report_at")
      Player.in_good_standing
        .joins("INNER JOIN (#{latest.to_sql}) open_reports ON open_reports.reported_id = accounts_players.id")
        .order("open_reports.latest_report_at DESC, accounts_players.id DESC")
    end

    def self.rows(players)
      players = players.to_a
      groups = Report.unhandled.where(reported_id: players.map(&:id)).group(:reported_id, :reason)
        .pluck(:reported_id, :reason, Arel.sql("COUNT(*)"), Arel.sql("MAX(created_at)"))
        .group_by(&:first)
      players.filter_map do |player|
        reasons = groups[player.id] or next
        per_reason = Report.reasons.keys.index_with { 0 }
        reasons.each { |_, reason, count, _| per_reason[reason] = count }
        Row.new(player:, counts: per_reason, total: per_reason.values.sum, latest_at: reasons.map(&:last).max)
      end
    end

    def self.size
      players.count
    end
  end
end
