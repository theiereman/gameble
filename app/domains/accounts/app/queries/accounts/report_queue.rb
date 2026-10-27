module Accounts
  # The staff's queue of reported players: every player in good standing
  # with open reports, the latest open report first. `players` is the
  # relation to page; `rows` reads, for a page of it, each player's open
  # reports per reason, their total and the latest one's time in one query,
  # so they agree, skipping a player whose reports were handled since the
  # page was read.
  #
  #   page = Accounts::ReportQueue.players.limit(50)
  #   Accounts::ReportQueue.rows(page) # => [Accounts::ReportQueue::Row, …]
  #   Accounts::ReportQueue.size       # => 3
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
