module Game
  class DuelStatMoves
    PER_DIRECTION = 3

    def initialize(changes)
      @changes = changes
    end

    def rises = card_moves.select { it.amount.positive? }.sort_by { [ -it.amount, it.card_season_id ] }.first(PER_DIRECTION)

    def falls = card_moves.select { it.amount.negative? }.sort_by { [ it.amount, it.card_season_id ] }.first(PER_DIRECTION)

    def to_a = rises + falls

    def rows
      to_a.map { { "card_season_id" => it.card_season_id, "stat" => it.stat.to_s, "from" => one_decimal(it.from), "to" => one_decimal(it.to) } }
    end

    private

    def card_moves
      @card_moves ||= @changes.reject { it.from.round == it.to.round }.group_by(&:card_id).each_value.map do |changes|
        changes.min_by { [ -it.amount.abs, DuelStat::STATS.index(it.stat), it.card_season_id ] }
      end
    end

    def one_decimal(percentile) = percentile.to_f.round(1)
  end
end
