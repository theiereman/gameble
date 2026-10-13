module PlayerStream
  TRADE_EVENTS = [
    Game::TradeProposed, Game::TradeCountered, Game::TradeAccepted,
    Game::TradeDeclined, Game::TradeCancelled, Game::TradeExpired
  ].freeze
  INVITATION_EVENTS = [ Game::InvitationSent, Game::InvitationAccepted, Game::InvitationCancelled ].freeze
  FRIENDSHIP_EVENTS = [ Game::FriendRemoved ].freeze
  EVENTS = (TRADE_EVENTS + INVITATION_EVENTS + FRIENDSHIP_EVENTS + [ Game::AchievementUnlocked ]).freeze
  CUT_OFF_EVENTS = [ Accounts::PlayerDeleted, Accounts::PlayerBanned ].freeze
  PRIVACY_EVENTS = [ Accounts::VisibilityChanged ].freeze

  BATCHES = :player_stream_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |notices| PlayerStreamJob.perform_later(notices) }

  class << self
    def streamables(player, locale = I18n.locale)
      [ player.stream_key, locale.to_s ]
    end

    def name(player, locale)
      streamables(player, locale).join(":")
    end

    def names(player)
      I18n.available_locales.map { name(player, it) }
    end

    def call(event)
      BATCH.add(notices(event))
    end

    def notices(event)
      data = event.data
      case event
      when *TRADE_EVENTS
        [ data[:proposer_id], data[:recipient_id] ].map { trades_notice(it) }
      when Game::InvitationAccepted
        [ friends_notice(data[:sender_id]).merge(friend_id: data[:recipient_id]), friends_notice(data[:recipient_id]) ]
      when Game::InvitationSent, Game::InvitationCancelled
        [ data[:sender_id], data[:recipient_id] ].map { friends_notice(it) }
      when Game::FriendRemoved
        former_friends_notices(data)
      when Game::AchievementUnlocked
        data[:retroactive] ? [] : [ { player_id: data[:player_id], achievement: data[:achievement] } ]
      when *CUT_OFF_EVENTS
        counterparts_notices(data[:player_id])
      when Accounts::VisibilityChanged
        data[:visibility] == "private" ? [ trades_notice(data[:player_id]) ] + trade_partners_notices(data[:player_id]) : []
      else
        []
      end
    end

    private

    def trades_notice(player_id) = { player_id:, topic: "trades" }

    def friends_notice(player_id) = { player_id:, topic: "friends" }

    def former_friends_notices(data)
      pair = [ data[:player_id], data[:friend_id] ]
      notices = pair.map { friends_notice(it) }
      data[:trade_ids].empty? ? notices : notices + pair.map { trades_notice(it) }
    end

    def counterparts_notices(player_id)
      counterparts = counterparts_of(player_id)
      counterparts[:trades].uniq.map { trades_notice(it) } + counterparts[:friends].map { friends_notice(it) }
    end

    def trade_partners_notices(player_id)
      counterparts_of(player_id)[:trades].uniq.map { trades_notice(it) }
    end

    def counterparts_of(player_id)
      player = Accounts::PlayerById.call(player_id)
      player ? Game::Counterparts.call(player) : { trades: [], friends: [] }
    end
  end
end
