module Game
  # The first player to discover a card's edition of the published season,
  # and when: nil when that edition has no recorded discovery (nothing is
  # backfilled). One query.
  #
  #   Game::PioneerOf.call(12) # => #<data Game::PioneerOf::Pioneer player=…, discovered_at=…>
  module PioneerOf
    Pioneer = Data.define(:player, :discovered_at)

    SQL = <<~SQL.squish.freeze
      SELECT accounts_players.*, game_first_discoveries.discovered_at AS pioneer_discovered_at
        FROM game_first_discoveries
        JOIN accounts_players ON accounts_players.id = game_first_discoveries.player_id
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_first_discoveries.card_season_id
       WHERE catalog_card_seasons.card_id = :card_id
         AND catalog_card_seasons.season_id = (
           SELECT id FROM catalog_seasons WHERE status = 'published' ORDER BY number DESC LIMIT 1)
       LIMIT 1
    SQL

    def self.call(card_id)
      player = Accounts::Player.find_by_sql([ SQL, { card_id: } ], preparable: false).first
      Pioneer.new(player:, discovered_at: player.pioneer_discovered_at) if player
    end
  end
end
