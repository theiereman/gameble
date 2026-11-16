module Game
  module ReachableFriends
    Row = Data.define(:player, :in_duel)

    def self.call(player, now: Time.current)
      return [] unless Visibility.open_to_friends?(player)

      friends = FriendsOf.call(player).select { Visibility.open_to_friends?(it) && it.reachable_until.present? && it.reachable_until > now }
      busy = DuelSeat.where(player_id: friends.map(&:id), status: %w[seated invited]).pluck(:player_id).to_set
      friends.map { Row.new(player: it, in_duel: busy.include?(it.id)) }
    end
  end
end
