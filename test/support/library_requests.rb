# Helpers of the request tests of the library, the public profile and the
# card detail: giving a player copies, reading a set's members, and counting
# a request's queries. The including test signs in with SteamSignIn.
module LibraryRequests
  # Copies of a card-season, last gained at `gained_at` (nil: before the
  # tracking of new cards, never new).
  def hold(player, card_season_id, quantity, gained_at: nil)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, last_gained_at: gained_at)
  end

  # The card-season ids of the set `key` of `season`, in slot order.
  def set_members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  # The test connection's query cache survives between integration requests:
  # it is cleared first, so every query of the request is counted.
  def assert_request_queries(count, &request)
    ActiveRecord::Base.connection.clear_query_cache
    assert_queries_count(count, &request)
  end
end
