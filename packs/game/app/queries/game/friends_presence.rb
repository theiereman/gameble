module Game
  # A player's friends with their presence (CAP-21, AD-24), read when the
  # page renders: nothing is tracked or broadcast. Each friend (as
  # Game::FriendsOf lists them, by name, banned ones left out) is in one
  # state:
  #
  # - :active  -- acted within ACTIVITY_WINDOW: online, doing `activity`
  #   (Game::Handlers::PlayerActivity's key), even before their last-seen
  #   time caught up;
  # - :online  -- seen within ONLINE_WINDOW (`last_seen_at` on the account,
  #   written by Accounts::NoteLastSeenJob);
  # - :offline -- last seen at `seen_at`, the later of both times, nil when
  #   never seen.
  #
  # The windows are tuned in play (AD-24); this is the one place they are
  # read from.
  #
  #   Game::FriendsPresence.call(player)         # => [Game::FriendsPresence::Row, ...]
  #   Game::FriendsPresence.online_count(player) # => 2
  module FriendsPresence
    # Seen this recently counts as online. Longer than the last-seen write's
    # throttle (Accounts::NoteLastSeen::THROTTLE).
    ONLINE_WINDOW = 5.minutes
    # An activity this recent is shown as what the friend is doing. Shorter
    # than ONLINE_WINDOW (online_count relies on it).
    ACTIVITY_WINDOW = 3.minutes

    Row = Data.define(:player, :state, :activity, :seen_at) do
      def online? = state != :offline
    end

    def self.call(player, now: Time.current)
      friends = FriendsOf.call(player)
      return [] if friends.empty?

      activities = PlayerState.where(player_id: friends.map(&:id))
        .pluck(:player_id, :last_activity, :last_activity_at).to_h { |id, *activity| [ id, activity ] }
      friends.map { |friend| row(friend, *activities[friend.id], now:) }
    end

    # How many of the player's friends are online (menu 04's "n en ligne"),
    # in one query whatever their number, for the hub: a friend is online
    # when seen or active within ONLINE_WINDOW, which is what `call` decides
    # since ACTIVITY_WINDOW is the shorter.
    def self.online_count(player, now: Time.current)
      return 0 unless player

      friend_ids = Friendship.of(player.id)
        .select(Arel.sql(format("CASE WHEN low_player_id = %d THEN high_player_id ELSE low_player_id END", player.id)))
      Accounts::Player.where(id: friend_ids, banned_at: nil)
        .joins("LEFT JOIN game_player_states ON game_player_states.player_id = accounts_players.id")
        .where("accounts_players.last_seen_at > :since OR game_player_states.last_activity_at > :since", since: now - ONLINE_WINDOW)
        .count
    end

    def self.row(friend, activity = nil, activity_at = nil, now:)
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
