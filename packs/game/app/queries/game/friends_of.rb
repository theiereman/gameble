module Game
  module FriendsOf
    def self.call(player)
      return [] unless player

      Accounts::Player.in_good_standing.where(id: Friendship.other_ids(player.id)).order(:persona_name, :id).to_a
    end
  end
end
