class DuelHistory
  Row = Data.define(:token, :outcome, :score, :other_score, :opponent)

  def initialize(player)
    @player = player
  end

  def record = @record ||= Game::DuelRecord.call(@player)

  def rows
    @rows ||= begin
      results = Game::RecentDuels.call(@player)
      opponents = Accounts::PlayersById.call(results.filter_map(&:opponent_id)).index_by(&:id)
      results.map do |result|
        Row.new(token: result.token, outcome: result.outcome, score: result.score, other_score: result.other_score,
          opponent: opponents[result.opponent_id])
      end
    end
  end
end
