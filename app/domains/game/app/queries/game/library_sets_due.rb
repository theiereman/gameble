module Game
  module LibrarySetsDue
    def self.call(limit:)
      CustomSet.steam_library
        .where(player_id: Accounts::Player.in_good_standing.select(:id))
        .order(Arel.sql("synced_at ASC NULLS FIRST"), :id)
        .limit(limit)
        .pluck(:player_id, :token)
    end
  end
end
