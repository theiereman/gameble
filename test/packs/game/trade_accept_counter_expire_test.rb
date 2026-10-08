require "test_helper"

class Game::TradeAcceptCounterExpireTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @one = catalog_card_seasons(:portal_one).id
    @two = catalog_card_seasons(:common_card_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    @four = catalog_card_seasons(:uncommon_card_one).id
    befriend(@alice, @bob)
    hold(@alice, @one, 3)
    hold(@alice, @two, 1)
    hold(@bob, @three, 2)
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity, last_gained_at: nil)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, last_gained_at:)
  end

  def holding(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)

  def holdings(player)
    Game::Holding.where(player_id: player.id).order(:card_season_id).pluck(:card_season_id, :quantity, :reserved).to_h { |id, *counts| [ id, counts ] }
  end

  def propose(player = @alice, recipient = @bob, offer: { @one => 2, @two => 1 }, request: { @three => 2 })
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  def accept(trade, player = @bob, revision: Game::Trade.find(trade.id).revision) = Game::AcceptTrade.new.call(player:, trade_id: trade.id, revision:)

  def counter(trade, player = @bob, offer: { @three => 1 }, request: { @one => 1 })
    Game::CounterTrade.new.call(player:, trade_id: trade.id, offer:, request:)
  end

  def sides(trade)
    Game::TradeItem.where(trade_id: trade.id).order(:side, :card_season_id).pluck(:side, :card_season_id, :quantity)
      .group_by(&:first).transform_values { |rows| rows.to_h { |_, id, quantity| [ id, quantity ] } }
  end

  def events(type, player = @alice) = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(player.id)).of_type(type).to_a

  def snapshot = [ holdings(@alice), holdings(@bob), Game::TradeItem.order(:id).pluck(:side, :card_season_id, :quantity), Game::Trade.order(:id).pluck(:status, :proposer_id, :expires_at) ]

  test "accepting swaps both sides at once, releases the offer, closes the trade and publishes once" do
    trade = propose

    result = accept(trade)

    assert_equal "accepted", result.value!.status
    assert_not_nil result.value!.closed_at
    assert_equal({ @one => [ 1, 0 ], @two => [ 0, 0 ], @three => [ 2, 0 ] }, holdings(@alice))
    assert_equal({ @one => [ 2, 0 ], @two => [ 1, 0 ], @three => [ 0, 0 ] }, holdings(@bob))
    assert_equal({ trade_id: trade.id, proposer_id: @alice.id, recipient_id: @bob.id }, events(Game::TradeAccepted).sole.data.symbolize_keys)
    assert Game::ProposeTrade.new.call(player: @bob, recipient: @alice, offer: { @one => 2 }, request: { @three => 1 }).success?,
      "the pair is free again and the received cards can be offered"
  end

  test "what each player receives is new on their collection, what they give is not marked" do
    long_ago = 3.days.ago
    hold(@bob, @one, 1, last_gained_at: long_ago)
    Game::PlayerState.find_or_initialize_by(player_id: @bob.id).update!(collection_seen_up_to: 2.days.ago)
    Game::PlayerState.find_or_initialize_by(player_id: @alice.id).update!(collection_seen_up_to: 2.days.ago)
    holding(@bob, @three).update_columns(last_gained_at: long_ago)
    trade = propose(offer: { @one => 2 }, request: { @three => 1 })

    accept(trade).value!

    bob = Game::CollectionSlots.call(@bob, [ @one, @three ])
    alice = Game::CollectionSlots.call(@alice, [ @one, @three ])
    assert bob.fetch(@one).new, "a card the receiver already held is new again"
    assert_not bob.fetch(@three).new, "a given card keeps its gain time"
    assert_in_delta long_ago, holding(@bob, @three).last_gained_at, 1
    assert alice.fetch(@three).new, "a card never held before is new"
    assert_equal 3, bob.fetch(@one).copies
  end

  test "the same card on both sides moves the net difference and marks only a rise" do
    hold(@bob, @one, 1, last_gained_at: 3.days.ago)
    trade = propose(offer: { @one => 2 }, request: { @one => 1 })

    accept(trade).value!

    assert_equal [ 2, 0 ], holdings(@alice)[@one]
    assert_nil holding(@alice, @one).last_gained_at, "alice's copies fell"
    assert_equal [ 2, 0 ], holdings(@bob)[@one]
    assert_in_delta Time.current, holding(@bob, @one).last_gained_at, 5
  end

  test "a requested card no longer free refuses the acceptance and nothing moves" do
    trade = propose
    befriend(@bob, @carol)
    hold(@carol, @one, 1)
    Game::ProposeTrade.new.call(player: @bob, recipient: @carol, offer: { @three => 1 }, request: { @one => 1 }).value!
    before = snapshot

    assert_equal Dry::Monads::Failure(:requested_cards_unavailable), accept(trade)
    assert_equal before, snapshot
    assert trade.reload.open?
    assert_empty events(Game::TradeAccepted)
  end

  test "a requested card the friend no longer holds at all refuses the acceptance" do
    hold(@bob, @four, 1)
    trade = propose(request: { @four => 1 })
    Game::Holding.where(player_id: @bob.id, card_season_id: @four).delete_all

    assert_equal Dry::Monads::Failure(:requested_cards_unavailable), accept(trade)
    assert_equal [ 3, 2 ], holdings(@alice)[@one]
  end

  test "a trade past its expiry cannot be accepted nor countered" do
    trade = propose

    travel_to(trade.expires_at - 1.second) { assert accept(trade).success? }
    trade = propose(@bob, @alice, offer: { @one => 1 }, request: { @three => 1 })
    travel_to(trade.expires_at, with_usec: true) do
      before = snapshot
      assert_equal Dry::Monads::Failure(:trade_expired), accept(trade, @alice)
      assert_equal Dry::Monads::Failure(:trade_expired), counter(trade, @alice, offer: { @three => 1 }, request: { @one => 1 })
      assert_equal before, snapshot
    end
  end

  test "only the recipient accepts; a stranger, a closed trade and no player are refused, a closed trade is not countered" do
    trade = propose

    assert_equal Dry::Monads::Failure(:not_allowed), accept(trade, @alice)
    assert_equal Dry::Monads::Failure(:trade_not_found), accept(trade, @carol)
    assert_equal Dry::Monads::Failure(:trade_not_found), Game::AcceptTrade.new.call(player: @bob, trade_id: 0, revision: "")
    assert_equal Dry::Monads::Failure(:player_required), accept(trade, nil)
    Game::CancelTrade.new.call(player: @alice, trade_id: trade.id).value!
    assert_equal Dry::Monads::Failure(:trade_not_open), accept(trade)
    assert_equal Dry::Monads::Failure(:trade_not_open), counter(trade)
    assert_equal({ @one => [ 3, 0 ], @two => [ 1, 0 ] }, holdings(@alice))
    assert_equal({ @three => [ 2, 0 ] }, holdings(@bob))
  end

  test "a banned proposer's trade cannot be accepted" do
    trade = propose
    @alice.update_columns(banned_at: Time.current)

    assert_equal Dry::Monads::Failure(:not_friends), accept(trade)
    assert_equal [ 2, 0 ], holdings(@bob)[@three]
  end

  test "a counter replaces both sides, moves the reservation, hands the turn over and restarts the 7 days" do
    trade = propose

    travel 3.days do
      result = counter(trade, offer: { @three => 1 }, request: { @one => 1, @two => 1 })

      trade = result.value!
      assert_equal [ @bob.id, @alice.id ], [ trade.proposer_id, trade.recipient_id ]
      assert trade.open?
      assert_in_delta Time.current, trade.proposed_at, 5
      assert_in_delta 7.days.from_now, trade.expires_at, 5
      assert_equal({ "offer" => { @three => 1 }, "request" => { @one => 1, @two => 1 } }, sides(trade))
      assert_equal({ @one => [ 3, 0 ], @two => [ 1, 0 ] }, holdings(@alice))
      assert_equal({ @three => [ 2, 1 ] }, holdings(@bob))
      assert_equal({ trade_id: trade.id, proposer_id: @bob.id, recipient_id: @alice.id }, events(Game::TradeCountered, @bob).sole.data.symbolize_keys)
    end
  end

  test "after a counter the turn is the other player's" do
    trade = propose
    counter(trade).value!

    assert_equal Dry::Monads::Failure(:not_allowed), accept(trade, @bob)
    assert_equal Dry::Monads::Failure(:not_allowed), counter(trade, @bob)
    assert_equal Dry::Monads::Failure(:not_allowed), Game::CancelTrade.new.call(player: @alice, trade_id: trade.id)
    assert_equal Dry::Monads::Failure(:not_allowed), Game::DeclineTrade.new.call(player: @bob, trade_id: trade.id)
    assert counter(trade, @alice, offer: { @one => 1 }, request: { @three => 2 }).success?, "the original proposer counters back"
    assert_equal({ @one => [ 3, 1 ], @two => [ 1, 0 ] }, holdings(@alice))
    assert_equal({ @three => [ 2, 0 ] }, holdings(@bob))

    accept(trade, @bob).value!

    assert_equal({ @one => [ 2, 0 ], @two => [ 1, 0 ], @three => [ 2, 0 ] }, holdings(@alice))
    assert_equal({ @one => [ 1, 0 ], @three => [ 0, 0 ] }, holdings(@bob))
  end

  test "a countered trade is accepted on its new sides" do
    trade = propose
    counter(trade, offer: { @three => 1 }, request: { @one => 1 }).value!

    accept(trade, @alice).value!

    assert_equal({ @one => [ 2, 0 ], @two => [ 1, 0 ], @three => [ 1, 0 ] }, holdings(@alice))
    assert_equal({ @one => [ 1, 0 ], @three => [ 1, 0 ] }, holdings(@bob))
    assert_equal({ trade_id: trade.id, proposer_id: @bob.id, recipient_id: @alice.id }, events(Game::TradeAccepted, @bob).sole.data.symbolize_keys)
  end

  test "a counter without enough free copies, or with bad sides, changes nothing" do
    trade = propose
    before = snapshot

    assert_equal Dry::Monads::Failure(:insufficient_copies), counter(trade, offer: { @three => 3 })
    assert_equal Dry::Monads::Failure(:insufficient_copies), counter(trade, offer: { @four => 1 })
    assert_equal Dry::Monads::Failure(:invalid_offer), counter(trade, offer: {})
    assert_equal Dry::Monads::Failure(:invalid_request), counter(trade, request: { @one => 0 })
    assert_equal Dry::Monads::Failure(:invalid_request), counter(trade, request: { Catalog::CardSeason.maximum(:id) + 1 => 1 })
    assert_equal Dry::Monads::Failure(:not_allowed), counter(trade, @alice)
    assert_equal Dry::Monads::Failure(:trade_not_found), counter(trade, @carol)
    assert_equal before, snapshot
    assert_empty events(Game::TradeCountered, @bob)
  end

  test "copies the counterer has reserved elsewhere cannot be offered in the counter" do
    trade = propose
    befriend(@bob, @carol)
    hold(@carol, @one, 1)
    Game::ProposeTrade.new.call(player: @bob, recipient: @carol, offer: { @three => 2 }, request: { @one => 1 }).value!

    assert_equal Dry::Monads::Failure(:insufficient_copies), counter(trade, offer: { @three => 1 })
  end

  test "expiring a due trade releases the offer and publishes once; a trade not yet due is refused" do
    trade = propose

    assert_equal Dry::Monads::Failure(:trade_not_expired), Game::ExpireTrade.new.call(player: @alice, trade_id: trade.id)
    travel_to(trade.expires_at, with_usec: true) do
      result = Game::ExpireTrade.new.call(player: @alice, trade_id: trade.id)

      assert_equal "expired", result.value!.status
      assert_equal({ @one => [ 3, 0 ], @two => [ 1, 0 ] }, holdings(@alice))
      assert_equal({ trade_id: trade.id, proposer_id: @alice.id, recipient_id: @bob.id }, events(Game::TradeExpired).sole.data.symbolize_keys)
      assert_equal Dry::Monads::Failure(:trade_not_open), Game::ExpireTrade.new.call(player: @alice, trade_id: trade.id)
      assert_equal Dry::Monads::Failure(:not_allowed), Game::ExpireTrade.new.call(player: @bob, trade_id: trade.id)
    end
  end

  test "the job expires trades 7 days after their last send or counter, and only those" do
    trade = propose
    befriend(@alice, @carol)
    hold(@carol, @four, 1)
    later = nil
    travel 2.days do
      later = Game::ProposeTrade.new.call(player: @carol, recipient: @alice, offer: { @four => 1 }, request: { @one => 1 }).value!
    end
    travel 6.days do
      counter(trade).value!
    end

    travel_to(later.expires_at, with_usec: true) { Game::ExpireTradesJob.perform_now }

    assert_equal "expired", later.reload.status
    assert_equal [ 1, 0 ], holdings(@carol)[@four]
    assert trade.reload.open?, "the counter restarted its 7 days"
    travel_to(trade.expires_at, with_usec: true) { Game::ExpireTradesJob.perform_now }
    assert_equal "expired", trade.reload.status
    assert_equal({ @three => [ 2, 0 ] }, holdings(@bob))
    assert_equal 1, events(Game::TradeExpired, @bob).size
  end

  test "the job expires a banned proposer's trade" do
    trade = propose
    @alice.update_columns(banned_at: Time.current)

    travel_to(trade.expires_at + 1.minute) { Game::ExpireTradesJob.perform_now }

    assert_equal "expired", trade.reload.status
    assert_equal({ @one => [ 3, 0 ], @two => [ 1, 0 ] }, holdings(@alice))
  end

  test "a trade whose expiry raises is reported and the others still expire" do
    first = propose
    befriend(@alice, @carol)
    hold(@carol, @four, 1)
    second = Game::ProposeTrade.new.call(player: @carol, recipient: @alice, offer: { @four => 1 }, request: { @one => 1 }).value!
    original = Game::ExpireTrade.method(:new)
    Game::ExpireTrade.define_singleton_method(:new) do |*args, **options|
      operation = original.call(*args, **options)
      operation.define_singleton_method(:call) { |player:, trade_id:| trade_id == first.id ? raise("boom") : super(player:, trade_id:) }
      operation
    end

    travel_to(second.expires_at, with_usec: true) do
      assert_error_reported(RuntimeError) { Game::ExpireTradesJob.perform_now }
    end

    assert first.reload.open?
    assert_equal "expired", second.reload.status
  ensure
    Game::ExpireTrade.singleton_class.remove_method(:new)
  end

  test "the job is scheduled in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal "Game::ExpireTradesJob", recurring.dig(env, "expire_trades", "class"), env
    end
  end


  test "accepting or declining terms the player did not see is refused and nothing moves" do
    trade = propose
    seen = Game::Trade.find(trade.id).revision
    counter(trade, @bob).value!
    counter(Game::Trade.find(trade.id), @alice, offer: { @one => 2 }, request: { @three => 1 }).value!
    before = snapshot

    assert_equal Dry::Monads::Failure(:trade_changed), accept(trade, revision: seen)
    assert_equal Dry::Monads::Failure(:trade_changed), Game::DeclineTrade.new.call(player: @bob, trade_id: trade.id, revision: seen)
    assert_equal Dry::Monads::Failure(:trade_changed), accept(trade, revision: nil)
    assert_equal before, snapshot
    assert Game::Trade.find(trade.id).open?
    assert_empty events(Game::TradeAccepted)
    assert accept(trade).success?
  end

  test "the terms of a trade change with every send and counter" do
    trade = propose
    first = Game::Trade.find(trade.id).revision

    counter(trade, @bob).value!

    assert_not_equal first, Game::Trade.find(trade.id).revision
  end

  test "a request beyond what the friend holds is refused when proposing and when countering" do
    assert_equal Dry::Monads::Failure(:request_exceeds_holdings), Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { @one => 1 }, request: { @three => 3 })
    assert_equal Dry::Monads::Failure(:request_exceeds_holdings), Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { @one => 1 }, request: { @four => 1 })
    trade = propose
    before = snapshot

    assert_equal Dry::Monads::Failure(:request_exceeds_holdings), counter(trade, offer: { @three => 1 }, request: { @one => 4 })
    assert_equal before, snapshot
  end

  test "proposing again to a friend whose trade is past its expiry closes that trade and releases its offer" do
    expired = propose

    travel_to(expired.expires_at + 1.second) do
      fresh = propose(offer: { @one => 3 })

      assert_equal "expired", expired.reload.status
      assert_equal [ "open", 3 ], [ fresh.status, holding(@alice, @one).reserved ]
      assert_equal 1, events(Game::TradeExpired).size
      assert_equal 1, Game::Trade.in_progress.count
    end
  end

  test "a trade not yet past its expiry still blocks a new proposal" do
    propose

    travel_to(Game::Trade.sole.expires_at - 1.second) do
      assert_equal Dry::Monads::Failure(:trade_already_open), Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { @one => 1 }, request: { @three => 1 })
    end
  end
end
