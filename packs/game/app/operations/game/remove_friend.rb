module Game
  class RemoveFriend < Operation
    def call(player:, friend:)
      player = step require_player(player)
      step friend_of(player, friend)

      transaction do
        TradeLocks.players(player.id, friend.id)
        step unfriend(player, friend)
        cancelled = step CancelOpenTrades.new.call(player:, partner: friend)
        step publish(FriendRemoved.new(data: { player_id: player.id, friend_id: friend.id, trade_ids: cancelled.map(&:id) }),
          stream_name: stream_name(player.id))
        friend
      end
    end

    private

    def friend_of(player, friend)
      friend.is_a?(Accounts::Player) && friend.persisted? && FriendshipBetween.call(player, friend) ? Success() : Failure(:not_a_friend)
    end

    def unfriend(player, friend)
      low, high = [ player.id, friend.id ].minmax
      Friendship.where(low_player_id: low, high_player_id: high).delete_all.zero? ? Failure(:not_a_friend) : Success()
    end
  end
end
