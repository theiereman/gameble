module Game
  module DuelAchievementMetrics
    FINISHED_DUEL = "game_duels AS duel JOIN game_duel_seats AS seat ON seat.duel_id = duel.id".freeze
    OWN_FINISHED_DUELS = "#{FINISHED_DUEL} WHERE duel.state = 'finished' AND seat.player_id = :player_id".freeze
    OWN_WINS = "#{OWN_FINISHED_DUELS} AND duel.result = seat.role".freeze

    OWN_SCORE = "CASE seat.role WHEN 'challenger' THEN duel.challenger_score ELSE duel.opponent_score END".freeze
    OTHER_SCORE = "CASE seat.role WHEN 'challenger' THEN duel.opponent_score ELSE duel.challenger_score END".freeze

    OPPONENTS_SQL = <<~SQL.squish.freeze
      SELECT COUNT(DISTINCT COALESCE(other.player_id::text, other.stream_key::text)) FROM #{FINISHED_DUEL}
        JOIN game_duel_seats AS other ON other.duel_id = duel.id AND other.role <> seat.role
       WHERE duel.state = 'finished' AND seat.player_id = :player_id
    SQL

    ROUNDS_WON_BY_OWN_MOVE = <<~SQL.squish.freeze
      game_duel_rounds AS round
        JOIN game_duels AS duel ON duel.id = round.duel_id AND duel.state = 'finished'
        JOIN game_duel_seats AS seat ON seat.duel_id = duel.id AND seat.role = round.winner
       WHERE seat.player_id = :player_id
         AND NOT (CASE WHEN round.caller = seat.role THEN round.caller_automatic ELSE round.answer_automatic END)
    SQL

    WINNER_ROLE = "seat.role".freeze
    LOSER_ROLE = "CASE seat.role WHEN 'challenger' THEN 'opponent' ELSE 'challenger' END".freeze
    WINNING_CARD = "CASE WHEN round.caller = seat.role THEN round.caller_card_season_id ELSE round.answer_card_season_id END".freeze
    LOSING_CARD = "CASE WHEN round.caller = seat.role THEN round.answer_card_season_id ELSE round.caller_card_season_id END".freeze

    def self.played_rarity(role, card_season_id)
      <<~SQL.squish
        (SELECT (card ->> 'rarity')::integer
           FROM jsonb_array_elements(CASE #{role} WHEN 'challenger' THEN duel.challenger_cards ELSE duel.opponent_cards END) AS card
          WHERE (card ->> 'card_season_id')::bigint = #{card_season_id})
      SQL
    end

    COMMON_BEATS_LEGENDARY_SQL = format(<<~SQL.squish, Catalog::Rarity::TIERS.key(:common), Catalog::Rarity::TIERS.key(:legendary)).freeze
      SELECT COUNT(*) FROM #{ROUNDS_WON_BY_OWN_MOVE}
         AND #{played_rarity(WINNER_ROLE, WINNING_CARD)} = %d
         AND #{played_rarity(LOSER_ROLE, LOSING_CARD)} = %d
    SQL

    SQL = {
      duels_finished: "SELECT COUNT(*) FROM #{OWN_FINISHED_DUELS}",
      duels_won: "SELECT COUNT(*) FROM #{OWN_WINS}",
      common_beats_legendary_rounds: COMMON_BEATS_LEGENDARY_SQL,
      shutout_duels: "SELECT COUNT(*) FROM #{OWN_WINS} AND #{OWN_SCORE} = #{DuelRules::ROUNDS} AND #{OTHER_SCORE} = 0",
      margin_wins: "SELECT COUNT(*) FROM #{OWN_WINS} AND duel.challenger_score = duel.opponent_score",
      distinct_duel_opponents: OPPONENTS_SQL,
      distinct_stats_won: "SELECT COUNT(DISTINCT round.stat) FROM #{ROUNDS_WON_BY_OWN_MOVE}"
    }.freeze
  end
end
