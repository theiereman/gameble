module Accounts
  # The staff's queue of reported players: every player in good standing
  # with open reports, the latest open report first. `players` is the
  # relation to page; `rows` reads, for a page of it, each player's open
  # reports per reason, their total and the latest one's time, skipping a
  # player whose reports were handled since the page was read.
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
      reports = Report.unhandled.where(reported_id: players.map(&:id))
      counts = reports.group(:reported_id, :reason).count
      latest = reports.group(:reported_id).maximum(:created_at)
      players.filter_map do |player|
        latest_at = latest[player.id] or next
        per_reason = Report.reasons.keys.index_with { |reason| counts.fetch([ player.id, reason ], 0) }
        Row.new(player:, counts: per_reason, total: per_reason.values.sum, latest_at:)
      end
    end

    def self.size
      players.count
    end
  end
end
