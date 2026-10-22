module Game
  # The first player to discover a card-season (one edition of a card), and
  # when: nil when that edition has no recorded discovery (nothing is
  # backfilled). One query.
  #
  #   Game::PioneerOf.call(12) # => #<data Game::PioneerOf::Pioneer player=…, discovered_at=…>
  module PioneerOf
    Pioneer = Data.define(:player, :discovered_at)

    SQL = <<~SQL.squish.freeze
      SELECT accounts_players.*, game_first_discoveries.discovered_at AS pioneer_discovered_at
        FROM game_first_discoveries
        JOIN accounts_players ON accounts_players.id = game_first_discoveries.player_id
       WHERE game_first_discoveries.card_season_id = :card_season_id
       LIMIT 1
    SQL

    def self.call(card_season_id)
      player = Accounts::Player.find_by_sql([ SQL, { card_season_id: } ], preparable: false).first
      Pioneer.new(player:, discovered_at: player.pioneer_discovered_at) if player
    end
  end
end
