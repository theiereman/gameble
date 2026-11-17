class DuelHistory
  Row = Data.define(:token, :outcome, :score, :other_score, :opponent)

  def initialize(player)
    @player = player
  end

  def record = @record ||= Game::DuelRecord.call(@player)

  def rows
    @rows ||= Game::RecentDuels.call(@player).map do |result|
      Row.new(token: result.token, outcome: result.outcome, score: result.score, other_score: result.other_score,
        opponent: Accounts::PlayerById.call(result.opponent_id))
    end
  end
end
