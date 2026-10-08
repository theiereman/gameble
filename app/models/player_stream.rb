module PlayerStream
  TRADE_EVENTS = [
    Game::TradeProposed, Game::TradeCountered, Game::TradeAccepted,
    Game::TradeDeclined, Game::TradeCancelled, Game::TradeExpired
  ].freeze
  INVITATION_EVENTS = [ Game::InvitationSent, Game::InvitationAccepted ].freeze
  EVENTS = (TRADE_EVENTS + INVITATION_EVENTS).freeze
  CUT_OFF_EVENTS = [ Accounts::PlayerDeleted, Accounts::PlayerBanned ].freeze

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
      when Game::InvitationSent
        [ data[:sender_id], data[:recipient_id] ].map { friends_notice(it) }
      when *CUT_OFF_EVENTS
        counterparts_notices(data[:player_id])
      else
        []
      end
    end

    private

    def trades_notice(player_id) = { player_id:, topic: "trades" }

    def friends_notice(player_id) = { player_id:, topic: "friends" }

    def counterparts_notices(player_id)
      player = Accounts::PlayerById.call(player_id)
      return [] unless player

      counterparts = Game::Counterparts.call(player)
      counterparts[:trades].uniq.map { trades_notice(it) } + counterparts[:friends].map { friends_notice(it) }
    end
  end
end
