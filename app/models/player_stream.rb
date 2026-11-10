module PlayerStream
  TRADE_EVENTS = [
    Game::TradeProposed, Game::TradeCountered, Game::TradeAccepted,
    Game::TradeDeclined, Game::TradeCancelled, Game::TradeExpired
  ].freeze
  INVITATION_EVENTS = [ Game::InvitationSent, Game::InvitationAccepted, Game::InvitationCancelled, Game::InvitationIgnored ].freeze
  FRIENDSHIP_EVENTS = [ Game::FriendRemoved ].freeze
  SEEN_EVENTS = [ Game::TradeSeen ].freeze
  BALANCE_EVENTS = [
    Game::Market::CardsEntrusted, Game::Market::CardListed, Game::Market::AuctionSold, Game::Market::AuctionUnsold, Game::Market::ListingWithdrawn,
    Game::Market::BidPlaced
  ].freeze
  EVENTS = (TRADE_EVENTS + SEEN_EVENTS + INVITATION_EVENTS + FRIENDSHIP_EVENTS +
    [ Game::AchievementUnlocked, Game::AchievementClaimed, Game::CardBackUnlocked, Game::DailyBonusCollected ] + BALANCE_EVENTS).freeze
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

    def reacted(owner_ids)
      BATCH.add(owner_ids.map { reactions_notice(it) })
    end

    def notices(event)
      data = event.data
      case event
      when *TRADE_EVENTS
        [ data[:proposer_id], data[:recipient_id] ].map { trades_notice(it) }
      when *SEEN_EVENTS
        [ trades_notice(data[:player_id]) ]
      when Game::InvitationAccepted
        [ friends_notice(data[:sender_id]).merge(friend_id: data[:recipient_id]), friends_notice(data[:recipient_id]) ]
      when Game::InvitationSent, Game::InvitationCancelled
        [ data[:sender_id], data[:recipient_id] ].map { friends_notice(it) }
      when Game::InvitationIgnored
        [ friends_notice(data[:recipient_id]) ]
      when Game::FriendRemoved
        former_friends_notices(data)
      when Game::AchievementUnlocked
        data[:retroactive] ? [] : [ { player_id: data[:player_id], achievement: data[:achievement] } ]
      when Game::AchievementClaimed
        [ { player_id: data[:player_id], claimed: true } ]
      when Game::CardBackUnlocked
        data[:retroactive] ? [] : [ { player_id: data[:player_id], card_back: data[:back] } ]
      when Game::DailyBonusCollected
        [ { player_id: data[:player_id], topic: "bank" } ]
      when Game::Market::CardListed
        [ balance_notice(data[:seller_id]) ]
      when Game::Market::AuctionSold
        balance_notices(data.values_at(:seller_id, :winner_id, :outbid_player_id))
      when Game::Market::BidPlaced
        balance_notices(data.values_at(:bidder_id, :outbid_player_id))
      when Game::Market::AuctionUnsold
        balance_notices([ data[:seller_id] ])
      when Game::Market::ListingWithdrawn
        balance_notices(data.values_at(:seller_id, :leader_id))
      when *BALANCE_EVENTS
        [ balance_notice(data[:player_id]) ]
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

    def balance_notice(player_id) = { player_id:, balance: true }

    def balance_notices(player_ids) = player_ids.compact.uniq.map { balance_notice(it) }

    def friends_notice(player_id) = { player_id:, topic: "friends" }

    def reactions_notice(player_id) = { player_id:, topic: "reactions" }

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
