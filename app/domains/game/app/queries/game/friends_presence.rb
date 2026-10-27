module Game
  module FriendsPresence
    ONLINE_WINDOW = 5.minutes
    ACTIVITY_WINDOW = 3.minutes

    Row = Data.define(:player, :state, :activity, :seen_at) do
      def online? = %i[online active].include?(state)
    end

    def self.call(player, now: Time.current)
      friends = FriendsOf.call(player)
      return [] if friends.empty?

      activities = PlayerState.where(player_id: friends.map(&:id))
        .pluck(:player_id, :last_activity, :last_activity_at).to_h { |id, *activity| [ id, activity ] }
      friends.map { |friend| row(friend, *activities[friend.id], now:) }
    end

    def self.of(friend, now: Time.current)
      row(friend, *PlayerState.where(player_id: friend.id).pick(:last_activity, :last_activity_at), now:)
    end

    def self.online_count(player, now: Time.current)
      return 0 unless player

      friend_ids = Friendship.of(player.id)
        .select(Arel.sql(format("CASE WHEN low_player_id = %d THEN high_player_id ELSE low_player_id END", player.id)))
      Accounts::Player.in_good_standing.where(id: friend_ids).where.not(visibility: Accounts::Player.visibilities[:private])
        .joins("LEFT JOIN game_player_states ON game_player_states.player_id = accounts_players.id")
        .where("accounts_players.last_seen_at > :since OR game_player_states.last_activity_at > :since", since: now - ONLINE_WINDOW)
        .count
    end

    def self.row(friend, activity = nil, activity_at = nil, now:)
      return Row.new(player: friend, state: :private, activity: nil, seen_at: nil) unless Visibility.open_to_friends?(friend)

      seen_at = [ friend.last_seen_at, activity_at ].compact.max
      if activity && activity_at && activity_at > now - ACTIVITY_WINDOW
        Row.new(player: friend, state: :active, activity:, seen_at:)
      elsif seen_at && seen_at > now - ONLINE_WINDOW
        Row.new(player: friend, state: :online, activity: nil, seen_at:)
      else
        Row.new(player: friend, state: :offline, activity: nil, seen_at:)
      end
    end
    private_class_method :row
  end
end
