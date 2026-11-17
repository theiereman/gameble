module Game
  module ProfileActivity
    Activity = Data.define(:packs_opened, :first_discoveries, :trades_concluded, :duel_wins, :duel_losses, :duel_draws)
    NONE = Activity.new(packs_opened: 0, first_discoveries: 0, trades_concluded: 0, duel_wins: 0, duel_losses: 0, duel_draws: 0)

    SQL = <<~SQL.squish.freeze
      SELECT
        (#{AchievementProgress::PACKS_OPENED_SQL}),
        (SELECT COUNT(*) FROM game_first_discoveries WHERE player_id = :player_id),
        (#{AchievementProgress::TRADES_ACCEPTED_SQL}),
        (#{DuelRecord::WINS_SQL}),
        (#{DuelRecord::LOSSES_SQL}),
        (#{DuelRecord::DRAWS_SQL})
    SQL

    def self.call(player)
      return NONE if player.nil?

      row = Pack.connection.select_rows(Pack.sanitize_sql_array([ SQL, { player_id: player.id } ]), "Game::ProfileActivity").first
      Activity.new(*row.map(&:to_i))
    end
  end
end
