module Game
  # The first pull of a card in a season (CAP-13, AD-9, story 6.7): one row
  # per card-season, unique in the database, naming the player and the pack.
  # Written only by Game::OpenPack, in the opening's transaction; its insert
  # decides that Game::CardDiscovered is published, once.
  class FirstDiscovery < ApplicationRecord
    self.table_name = "game_first_discoveries"

    # Records the card-seasons of the opened `pack` nobody had pulled before,
    # in one insert by ascending card-season (two openings racing on the
    # same cards wait on each other in one order, never in a cycle); a card
    # already discovered is skipped and never fails. Answers the card-season
    # ids this opening discovered, ascending.
    def self.record(pack, now)
      rows = pack.card_season_ids.uniq.sort.map do |card_season_id|
        { card_season_id:, player_id: pack.player_id, pack_id: pack.id, discovered_at: now, created_at: now, updated_at: now }
      end
      insert_all(rows, unique_by: :card_season_id, returning: :card_season_id, record_timestamps: false)
        .rows.flatten.sort
    end
  end
end
