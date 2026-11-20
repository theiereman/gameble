module Game
  module DuelRecord
    Record = Data.define(:wins, :losses, :draws)
    NONE = Record.new(wins: 0, losses: 0, draws: 0)

    OWN_DUELS = "#{DuelAchievementMetrics::OWN_FINISHED_DUELS} AND duel.rules_version = #{DuelRules::VERSION}".freeze

    WINS_SQL = "SELECT COUNT(*) FROM #{OWN_DUELS} AND duel.result = seat.role".freeze
    LOSSES_SQL = "SELECT COUNT(*) FROM #{OWN_DUELS} AND duel.result <> 'draw' AND duel.result <> seat.role".freeze
    DRAWS_SQL = "SELECT COUNT(*) FROM #{OWN_DUELS} AND duel.result = 'draw'".freeze

    SQL = "SELECT (#{WINS_SQL}), (#{LOSSES_SQL}), (#{DRAWS_SQL})".freeze

    def self.call(player)
      return NONE if player.nil?

      row = Duel.connection.select_rows(Duel.sanitize_sql_array([ SQL, { player_id: player.id } ]), "Game::DuelRecord").first
      Record.new(*row.map(&:to_i))
    end
  end
end
