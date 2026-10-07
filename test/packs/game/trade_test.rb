require "test_helper"

# Game::ProposeTrade, CancelTrade and DeclineTrade (AD-6, AD-8, AD-10, story
# 5.4): friendship required, one open trade per pair, one to four cards per
# side with quantities, the offer reserved from the copies owned minus those
# reserved elsewhere, released on cancel and decline, one event each.
class Game::TradeTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @one = catalog_card_seasons(:portal_one).id
    @two = catalog_card_seasons(:common_card_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    befriend(@alice, @bob)
    hold(@alice, @one, 3)
    hold(@alice, @two, 1)
    hold(@bob, @three, 2)
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity, reserved: 0)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved:)
  end

  def reserved(player, card_season_id) = Game::Holding.find_by!(player_id: player.id, card_season_id:).reserved

  def propose(player = @alice, recipient = @bob, offer: { @one => 2 }, request: { @three => 1 })
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:)
  end

  def events(type) = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@alice.id)).of_type(type).to_a

  test "a proposal reserves exactly the offered copies and stores both sides" do
    trade = propose(offer: { @one => 2, @two => 1 }, request: { @three => 2 }).value!

    assert trade.open?
    assert_equal @alice.id, trade.proposer_id
    assert_equal @bob.id, trade.recipient_id
    assert_in_delta 7.days.from_now, trade.expires_at, 5
    assert_equal({ @one => 2, @two => 1 }, trade.offer_items.to_h { |item| [ item.card_season_id, item.quantity ] })
    assert_equal({ @three => 2 }, trade.request_items.to_h { |item| [ item.card_season_id, item.quantity ] })
    assert_equal [ 2, 1 ], [ reserved(@alice, @one), reserved(@alice, @two) ]
    assert_equal 0, reserved(@bob, @three), "the request is not reserved"
  end

  test "one event with identifiers only is published" do
    trade = propose.value!

    event = events(Game::TradeProposed).sole
    assert_equal({ trade_id: trade.id, proposer_id: @alice.id, recipient_id: @bob.id }, event.data.symbolize_keys)
  end

  test "non-friends, oneself, a banned player and no player are refused" do
    stranger = accounts_players(:administrator)
    assert_equal Dry::Monads::Failure(:not_friends), propose(@alice, stranger)
    assert_equal Dry::Monads::Failure(:not_friends), propose(@alice, @alice)
    befriend(@alice, accounts_players(:banned))
    assert_equal Dry::Monads::Failure(:not_friends), propose(@alice, accounts_players(:banned))
    assert_equal Dry::Monads::Failure(:not_friends), propose(@alice, nil)
    assert_equal Dry::Monads::Failure(:player_required), propose(Accounts::Player.new)
    assert_equal 0, reserved(@alice, @one)
    assert_empty events(Game::TradeProposed)
  end

  test "a second open trade for the pair is refused, in either direction" do
    propose.value!
    hold(@bob, catalog_card_seasons(:uncommon_card_one).id, 1)

    assert_equal Dry::Monads::Failure(:trade_already_open), propose
    assert_equal Dry::Monads::Failure(:trade_already_open), propose(@bob, @alice, offer: { @three => 1 }, request: { @one => 1 })
    assert_equal 2, reserved(@alice, @one)
    assert_equal 1, Game::Trade.count
  end

  test "the database holds one open trade per pair" do
    propose.value!
    clash = Game::Trade.new(low_player_id: [ @alice.id, @bob.id ].min, high_player_id: [ @alice.id, @bob.id ].max,
      proposer_id: @bob.id, recipient_id: @alice.id, proposed_at: Time.current, expires_at: 7.days.from_now)

    assert_raises(ActiveRecord::RecordNotUnique) { Game::Trade.transaction(requires_new: true) { clash.save! } }
    clash.status = "cancelled"
    assert clash.save, "a closed trade does not block the pair"
  end

  test "sides need one to four different cards with positive integer quantities" do
    cards = [ @one, @two, @three, catalog_card_seasons(:uncommon_card_one).id, catalog_card_seasons(:legendary_card_one).id ]
    [ {}, nil, [], { @one => 0 }, { @one => -1 }, { @one => 1.5 }, { @one => 1000 }, { @one => "0x10" }, { @one => "x" }, { 0 => 1 }, cards.to_h { |id| [ id, 1 ] } ].each do |bad|
      assert_equal Dry::Monads::Failure(:invalid_offer), propose(offer: bad), "offer #{bad.inspect}"
      assert_equal Dry::Monads::Failure(:invalid_request), propose(request: bad), "request #{bad.inspect}"
    end
    assert_equal Dry::Monads::Failure(:invalid_request), propose(request: { 0 => 1 })
    assert_equal Dry::Monads::Failure(:invalid_request), propose(request: { Catalog::CardSeason.maximum(:id) + 1 => 1 })
    assert_equal 0, Game::Trade.count
  end

  test "four different cards per side are accepted" do
    ids = [ @one, @two, catalog_card_seasons(:uncommon_card_one).id, catalog_card_seasons(:legendary_card_one).id ]
    ids.each { |id| Game::Holding.find_or_create_by!(player_id: @alice.id, card_season_id: id) { |holding| holding.quantity = 1 } }

    trade = propose(offer: ids.to_h { |id| [ id, 1 ] }, request: ids.to_h { |id| [ id, 1 ] }).value!

    assert_equal 4, trade.offer_items.size
    assert_equal 4, trade.request_items.size
  end

  test "a card not owned, or more copies than owned, is refused and nothing is reserved" do
    assert_equal Dry::Monads::Failure(:insufficient_copies), propose(offer: { @one => 4 })
    assert_equal Dry::Monads::Failure(:insufficient_copies), propose(offer: { @one => 1, catalog_card_seasons(:legendary_card_one).id => 1 })
    assert_equal Dry::Monads::Failure(:insufficient_copies), propose(offer: { @one => 1, @two => 2 })
    assert_equal [ 0, 0 ], [ reserved(@alice, @one), reserved(@alice, @two) ]
    assert_equal 0, Game::Trade.count
    assert_empty events(Game::TradeProposed)
  end

  test "copies reserved in another trade are not offered again, a card fully reserved is refused" do
    carol = accounts_players(:administrator)
    befriend(@alice, carol)
    propose(offer: { @one => 2 }).value!

    assert_equal Dry::Monads::Failure(:insufficient_copies), propose(@alice, carol, offer: { @one => 2 })
    assert propose(@alice, carol, offer: { @one => 1 }).success?
    dave = Accounts::Player.create!(steam_id: "76561197960287099", persona_name: "Dave")
    befriend(@alice, dave)
    assert_equal Dry::Monads::Failure(:insufficient_copies), propose(@alice, dave, offer: { @one => 1 }), "all three copies are reserved"
    assert_equal 3, reserved(@alice, @one)
  end

  test "cancelling releases the offer, closes the trade and publishes once" do
    trade = propose(offer: { @one => 2, @two => 1 }).value!

    result = Game::CancelTrade.new.call(player: @alice, trade_id: trade.id)

    assert_equal "cancelled", result.value!.status
    assert_not_nil result.value!.closed_at
    assert_equal [ 0, 0 ], [ reserved(@alice, @one), reserved(@alice, @two) ]
    assert_equal 1, events(Game::TradeCancelled).size
    assert_equal({ trade_id: trade.id, proposer_id: @alice.id, recipient_id: @bob.id }, events(Game::TradeCancelled).sole.data.symbolize_keys)
    assert propose.success?, "the pair is free again and the cards can be offered again"
  end

  test "declining releases the proposer's offer, closes the trade and publishes once" do
    trade = propose.value!

    result = Game::DeclineTrade.new.call(player: @bob, trade_id: trade.id)

    assert_equal "declined", result.value!.status
    assert_equal 0, reserved(@alice, @one)
    assert_equal 1, events(Game::TradeDeclined).size
  end

  test "only the proposer cancels and only the friend declines" do
    trade = propose.value!
    stranger = accounts_players(:administrator)

    assert_equal Dry::Monads::Failure(:not_allowed), Game::CancelTrade.new.call(player: @bob, trade_id: trade.id)
    assert_equal Dry::Monads::Failure(:not_allowed), Game::DeclineTrade.new.call(player: @alice, trade_id: trade.id)
    assert_equal Dry::Monads::Failure(:trade_not_found), Game::CancelTrade.new.call(player: stranger, trade_id: trade.id)
    assert_equal Dry::Monads::Failure(:trade_not_found), Game::DeclineTrade.new.call(player: @bob, trade_id: 0)
    assert_equal Dry::Monads::Failure(:player_required), Game::CancelTrade.new.call(player: nil, trade_id: trade.id)
    assert trade.reload.open?
    assert_equal 2, reserved(@alice, @one)
  end

  test "a closed trade closes no more, releases nothing twice and publishes nothing" do
    trade = propose.value!
    Game::CancelTrade.new.call(player: @alice, trade_id: trade.id).value!
    hold(@bob, catalog_card_seasons(:uncommon_card_one).id, 1)
    propose.value!

    assert_equal Dry::Monads::Failure(:trade_not_open), Game::CancelTrade.new.call(player: @alice, trade_id: trade.id)
    assert_equal Dry::Monads::Failure(:trade_not_open), Game::DeclineTrade.new.call(player: @bob, trade_id: trade.id)
    assert_equal 2, reserved(@alice, @one), "the second trade's reservation is untouched"
    assert_equal 1, events(Game::TradeCancelled).size
  end

  test "the database keeps reserved within quantity" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::Holding.transaction(requires_new: true) { Game::Holding.where(player_id: @alice.id, card_season_id: @one).update_all(reserved: 4) }
    end
  end
end
