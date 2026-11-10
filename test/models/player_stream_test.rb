require "test_helper"
require_relative "../support/feed_reactions"
require_relative "../support/market"
require_relative "../support/market_listings"

class PlayerStreamTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include FeedReactions
  include MarketListings
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @one = catalog_card_seasons(:portal_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    low, high = [ @alice.id, @bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Market::Settings.delete_all
    Game::Holding.create!(player_id: @alice.id, card_season_id: @one, quantity: 3, reserved: 0)
    Game::Holding.create!(player_id: @bob.id, card_season_id: @three, quantity: 2, reserved: 0)
  end

  def propose(player = @alice, recipient = @bob)
    Game::ProposeTrade.new.call(player:, recipient:, offer: { @one => 1 }, request: { @three => 1 })
  end

  def trades_for(*players) = players.map { { player_id: it.id, topic: "trades" } }

  def stream_jobs = enqueued_jobs.select { it[:job] == PlayerStreamJob }

  def batches = ActiveSupport::IsolatedExecutionState[PlayerStream::BATCHES] || {}

  test "a proposal enqueues one job after its commit, with a notice for each party" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ trades_for(@alice, @bob) ]) { assert propose.success? }
    assert_equal 1, stream_jobs.size
    assert_empty batches
  end

  test "every trade event tells both parties" do
    data = { trade_id: 1, proposer_id: @alice.id, recipient_id: @bob.id }

    PlayerStream::TRADE_EVENTS.each do |type|
      assert_equal trades_for(@alice, @bob), PlayerStream.notices(type.new(data:)), type.name
    end
  end

  test "a daily capsule collected tells its collector's open screens" do
    assert_equal [ { player_id: @alice.id, topic: "bank" } ], PlayerStream.notices(Game::DailyBonusCollected.new(data: { player_id: @alice.id, pack_id: 1 }))
    assert_includes PlayerStream::EVENTS, Game::DailyBonusCollected
  end

  test "opening a trade tells only the player who opened it" do
    data = { player_id: @alice.id, trade_id: 1 }

    assert_equal [ { player_id: @alice.id, topic: "trades" } ], PlayerStream.notices(Game::TradeSeen.new(data:))
  end

  test "an invitation and its cancelling tell both players, and its acceptance names the accepting friend to the sender" do
    data = { invitation_id: 1, sender_id: @alice.id, recipient_id: @bob.id }

    assert_equal [ { player_id: @alice.id, topic: "friends" }, { player_id: @bob.id, topic: "friends" } ],
      PlayerStream.notices(Game::InvitationSent.new(data:))
    assert_equal [ { player_id: @alice.id, topic: "friends" }, { player_id: @bob.id, topic: "friends" } ],
      PlayerStream.notices(Game::InvitationCancelled.new(data:))
    assert_equal [ { player_id: @alice.id, topic: "friends", friend_id: @bob.id }, { player_id: @bob.id, topic: "friends" } ],
      PlayerStream.notices(Game::InvitationAccepted.new(data:))
  end

  test "an ignored invitation tells its recipient alone, so the sender never learns of it" do
    data = { invitation_id: 1, sender_id: @alice.id, recipient_id: @bob.id }

    assert_equal [ { player_id: @bob.id, topic: "friends" } ], PlayerStream.notices(Game::InvitationIgnored.new(data:))
  end

  test "ignoring an invitation enqueues the recipient's notice once it commits" do
    invitation = Game::Invitation.create!(sender_id: accounts_players(:administrator).id, recipient_id: @bob.id)

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @bob.id, topic: "friends" } ] ]) do
      Game::IgnoreInvitation.new.call(player: @bob, token: invitation.token).value!
    end
  end

  test "an unlocked achievement tells its player alone, with no topic; a retroactive one tells no one" do
    data = { player_id: @alice.id, achievement: "first_booster" }

    assert_equal [ { player_id: @alice.id, achievement: "first_booster" } ], PlayerStream.notices(Game::AchievementUnlocked.new(data:))
    assert_empty PlayerStream.notices(Game::AchievementUnlocked.new(data: data.merge(retroactive: true)))
  end

  test "an unlock enqueues its notice once it commits; a retroactive one enqueues nothing" do
    Game::Pack.create!(player_id: @alice.id, kind: :regular, season_id: catalog_seasons(:one).id, available_at: 1.minute.ago,
      opened_at: Time.current, card_season_ids: [ @one ] * Game::Pack::SIZE)

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @alice.id, achievement: "first_booster" } ] ]) do
      Game::GrantAchievement.new.call(player: @alice, achievement: :first_booster).value!
    end
    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      Game::GrantAchievement.new.call(player: @alice, achievement: :first_epic, retroactive: true).value!
    end
  end

  test "an unlocked card back tells its player alone; a retroactive one tells no one" do
    data = { player_id: @alice.id, back: "aurore" }

    assert_equal [ { player_id: @alice.id, card_back: "aurore" } ], PlayerStream.notices(Game::CardBackUnlocked.new(data:))
    assert_empty PlayerStream.notices(Game::CardBackUnlocked.new(data: data.merge(retroactive: true)))
  end

  test "a card back unlock enqueues its notice once it commits; a retroactive one, and a second unlock, enqueue nothing" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @alice.id, card_back: "aurore" } ] ]) do
      Game::UnlockCardBack.new.call(player: @alice, back: "aurore").value!
    end
    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      Game::UnlockCardBack.new.call(player: @alice, back: "aurore")
      Game::UnlockCardBack.new.call(player: @alice, back: "centurion", retroactive: true).value!
    end
  end

  test "an entrustment enqueues one balance job after its commit, and a refused one none" do
    settings = open_market!
    assert_includes PlayerStream::EVENTS, Game::Market::CardsEntrusted
    assert_equal [ { player_id: @alice.id, balance: true } ],
      PlayerStream.notices(Game::Market::CardsEntrusted.new(data: { player_id: @alice.id }))

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @alice.id, balance: true } ] ]) do
      assert Game::Market::EntrustCards.new.call(player: @alice, lines: { @one => 1 }, settings_token: settings.token).success?
    end
    assert_equal 1, stream_jobs.size
    assert_empty batches
  end

  test "a listing yields the seller's balance notice" do
    assert_includes PlayerStream::EVENTS, Game::Market::CardListed
    assert_equal [ { player_id: @alice.id, balance: true } ],
      PlayerStream.notices(Game::Market::CardListed.new(data: { listing_id: 1, seller_id: @alice.id, card_season_id: @one }))
  end

  test "a refused entrustment enqueues nothing" do
    settings = close_market!

    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      Game::Market::EntrustCards.new.call(player: @alice, lines: { @one => 1 }, settings_token: settings.token)
    end
  end

  test "other events tell nothing" do
    assert_empty PlayerStream.notices(Game::PackOpened.new(data: { player_id: @alice.id, pack_id: 1 }))
  end

  test "sending and accepting an invitation enqueue their notices" do
    stranger = accounts_players(:administrator)

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: stranger.id, topic: "friends" }, { player_id: @alice.id, topic: "friends" } ] ]) do
      Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!
    end
    invitation = Game::Invitation.pending.find_by!(sender_id: stranger.id)
    assert_enqueued_with(job: PlayerStreamJob,
      args: [ [ { player_id: stranger.id, topic: "friends", friend_id: @alice.id }, { player_id: @alice.id, topic: "friends" } ] ]) do
      Game::AcceptInvitation.new.call(player: @alice, token: invitation.token).value!
    end
  end

  test "cancelling an invitation enqueues a notice for each player" do
    stranger = accounts_players(:administrator)
    invitation = Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: stranger.id, topic: "friends" }, { player_id: @alice.id, topic: "friends" } ] ]) do
      Game::CancelInvitation.new.call(player: stranger, token: invitation.token).value!
    end
  end

  test "a removed friendship refreshes both players' friends, and their trades only when a trade was cancelled, naming no friend" do
    friends = [ { player_id: @alice.id, topic: "friends" }, { player_id: @bob.id, topic: "friends" } ]
    data = { player_id: @alice.id, friend_id: @bob.id }

    assert_equal friends, PlayerStream.notices(Game::FriendRemoved.new(data: data.merge(trade_ids: [])))
    assert_equal friends + trades_for(@alice, @bob), PlayerStream.notices(Game::FriendRemoved.new(data: data.merge(trade_ids: [ 1 ])))
  end

  test "removing a friend enqueues the notices once it commits, with the trades of the cancelled trade" do
    propose.value!
    clear_enqueued_jobs

    notices = [ { player_id: @bob.id, topic: "friends" }, { player_id: @alice.id, topic: "friends" } ] + trades_for(@bob, @alice)

    assert_enqueued_with(job: PlayerStreamJob, args: [ notices ]) do
      Game::RemoveFriend.new.call(player: @bob, friend: @alice).value!
    end
    assert_equal 1, stream_jobs.size
  end

  test "a refused operation enqueues nothing" do
    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      assert propose(@alice, accounts_players(:administrator)).failure?
    end
  end

  test "the notices of one transaction leave together once it commits, and nothing is broadcast inside it" do
    perform_enqueued_jobs(only: PlayerStreamJob) do
      ApplicationRecord.transaction do
        trade = propose.value!
        Game::CancelTrade.new.call(player: @alice, trade_id: trade.id).value!

        assert_empty stream_jobs, "nothing is enqueued before the commit"
        assert_no_broadcasts PlayerStream.name(@bob, :en)
      end
    end

    performed = performed_jobs.select { it[:job] == PlayerStreamJob }
    assert_equal 1, performed.size
    assert_equal [ trades_for(@alice, @bob) * 2 ], ActiveJob::Arguments.deserialize(performed.sole[:args])
    assert_broadcasts PlayerStream.name(@bob, :en), 1
    assert_broadcasts PlayerStream.name(@bob, :fr), 1
    assert_empty batches
  end

  test "a transaction rolled back leaves nothing" do
    ApplicationRecord.transaction do
      assert propose.success?
      raise ActiveRecord::Rollback
    end

    assert_empty stream_jobs
    assert_empty batches
    assert_not Game::Trade.exists?
  end

  test "deleting a player tells their trade partners and friends, found before they are dropped" do
    propose.value!
    stranger = accounts_players(:administrator)
    Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!
    clear_enqueued_jobs

    assert Accounts::DeletePlayer.new.call(player: @alice).success?

    expected = [ { player_id: @bob.id, topic: "trades" }, { player_id: @bob.id, topic: "friends" }, { player_id: stranger.id, topic: "friends" } ]
    assert_equal [ expected ], stream_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
    assert_equal "cancelled", Game::Trade.sole.status
  end

  test "deleting a player tells a stranger whose invitation they ignored, still pending on the stranger's side" do
    propose.value!
    stranger = accounts_players(:administrator)
    invitation = Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!
    Game::IgnoreInvitation.new.call(player: @alice, token: invitation.token).value!
    clear_enqueued_jobs

    assert Accounts::DeletePlayer.new.call(player: @alice).success?

    expected = [ { player_id: @bob.id, topic: "trades" }, { player_id: @bob.id, topic: "friends" }, { player_id: stranger.id, topic: "friends" } ]
    assert_equal [ expected ], stream_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
  end

  test "going private tells the player and their trade partners on either side, found before the trades are cancelled" do
    carol = accounts_players(:administrator)
    low, high = [ @alice.id, carol.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: carol.id, card_season_id: @three, quantity: 1, reserved: 0)
    propose.value!
    Game::ProposeTrade.new.call(player: carol, recipient: @alice, offer: { @three => 1 }, request: { @one => 1 }).value!
    clear_enqueued_jobs

    assert Accounts::SetVisibility.new.call(player: @alice, visibility: "private").success?

    notices = stream_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }.sole
    assert_equal trades_for(@alice, @bob, carol).sort_by { it[:player_id] }, notices.sort_by { it[:player_id] }
    assert_equal %w[cancelled cancelled], Game::Trade.pluck(:status)
  end

  test "going friends only or public tells no one" do
    propose.value!
    clear_enqueued_jobs

    Accounts::SetVisibility.new.call(player: @alice, visibility: "friends_only").value!

    assert_empty stream_jobs
  end

  test "a ban tells the banned player's friends" do
    banned = Accounts::PlayerBanned.new(data: { player_id: @alice.id })

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @bob.id, topic: "friends" } ] ]) do
      ApplicationRecord.transaction do
        @alice.update!(banned_at: Time.current)
        Rails.configuration.event_store.publish(banned, stream_name: "Accounts::Player-#{@alice.id}")
      end
    end
    assert_not Game::Friendship.of(@alice.id).exists?
  end

  test "a new player's first reaction to an entry tells its owner once it commits; reacting again, changing or withdrawing tells no one" do
    entry = feed_entry_of(@alice)

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @alice.id, topic: "reactions" } ] ]) do
      react(@bob, entry, "heart").value!
    end
    assert_empty batches

    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      react(@bob, entry, "wow").value!
      react(@bob, entry, nil).value!
      react(@bob, entry, "heart").value!
      react(@alice, entry, "gg").value!
    end
  end

  test "the reactions of one transaction tell each owner once" do
    first = feed_entry_of(@alice)
    second = feed_entry_of(@alice)

    ApplicationRecord.transaction do
      react(@bob, first, "heart").value!
      react(@bob, second, "heart").value!
    end

    assert_equal 1, stream_jobs.size
  end

  test "a sale tells the seller, the winner and the outbid player, once each" do
    data = { listing_id: 1, seller_id: @alice.id, winner_id: @bob.id, card_season_id: @one, final_price: 10, surplus: 0, outbid_player_id: @alice.id, outbid_released: 5 }

    notices = PlayerStream.notices(Game::Market::AuctionSold.new(data:)).select { it[:balance] }

    assert_equal [ @alice.id, @bob.id ], notices.map { it[:player_id] }
  end

  test "a sale tells the bell of the seller, the winner and the bidder it displaced, once each" do
    carol = accounts_players(:administrator)
    data = { listing_id: 1, seller_id: @alice.id, winner_id: @bob.id, card_season_id: @one, final_price: 10, surplus: 0, outbid_player_id: carol.id, outbid_released: 5 }

    notices = PlayerStream.notices(Game::Market::AuctionSold.new(data:))

    assert_equal [ carol.id, @bob.id, @alice.id ], notices.select { it[:topic] }.map { it[:player_id] }
  end

  test "a bid tells the bidder and the outbid player, once each" do
    data = { listing_id: 1, bidder_id: @bob.id, branch: "new_leader", outbid_player_id: @alice.id, outbid_released: 5 }

    notices = PlayerStream.notices(Game::Market::BidPlaced.new(data:))

    assert_equal [ @bob.id, @alice.id ], notices.select { it[:balance] }.map { it[:player_id] }
    assert_equal [ { player_id: @alice.id, topic: "market", outbid_listing_id: 1 }, { player_id: @bob.id, topic: "market" } ], notices.select { it[:topic] }
  end

  test "a bid that outbids nobody tells the bidder alone" do
    data = { listing_id: 1, bidder_id: @bob.id, branch: "raise", outbid_player_id: nil, outbid_released: 0 }

    assert_equal [ { player_id: @bob.id, balance: true }, { player_id: @bob.id, topic: "market" } ], PlayerStream.notices(Game::Market::BidPlaced.new(data:))
  end

  test "a bid over the bidder's own lead names no outbid listing" do
    data = { listing_id: 1, bidder_id: @bob.id, branch: "new_leader", outbid_player_id: @bob.id, outbid_released: 5 }

    assert_equal [ { player_id: @bob.id, topic: "market" } ], PlayerStream.notices(Game::Market::BidPlaced.new(data:)).select { it[:topic] }
  end

  test "a bid that outbids the bidder's own earlier lead does not duplicate the notice" do
    data = { listing_id: 1, bidder_id: @bob.id, branch: "new_leader", outbid_player_id: @bob.id, outbid_released: 5 }

    assert_equal [ { player_id: @bob.id, balance: true } ], PlayerStream.notices(Game::Market::BidPlaced.new(data:)).select { it[:balance] }
  end

  test "a sale, a withdrawal or an unsold end tells the market topic to every bidder of the listing" do
    carol = accounts_players(:administrator)
    open_market!
    listing = listing!(seller: @alice, card_season: catalog_card_seasons(:portal_one))
    [ @bob, carol ].each { Game::Market::Bid.create!(listing:, player: it, maximum: 30_000, price_after: 20_000, outcome: "beaten") }
    sold = Game::Market::AuctionSold.new(data: { listing_id: listing.id, seller_id: @alice.id, winner_id: @bob.id, card_season_id: @one, final_price: 10, surplus: 0, outbid_player_id: nil, outbid_released: 0 })
    withdrawn = Game::Market::ListingWithdrawn.new(data: { listing_id: listing.id, seller_id: @alice.id, leader_id: nil, released: 0 })

    assert_includes PlayerStream.notices(sold).select { it[:topic] }.map { it[:player_id] }, carol.id
    unsold = Game::Market::AuctionUnsold.new(data: { listing_id: listing.id, seller_id: @alice.id })

    assert_equal [ @bob.id, carol.id ].sort, PlayerStream.notices(withdrawn).select { it[:topic] }.map { it[:player_id] }.sort
    assert_equal [ @alice.id, @bob.id, carol.id ].sort, PlayerStream.notices(unsold).select { it[:topic] }.map { it[:player_id] }.sort
  end

  test "an unsold auction tells its seller" do
    notices = PlayerStream.notices(Game::Market::AuctionUnsold.new(data: { listing_id: 1, seller_id: @alice.id }))

    assert_equal [ { player_id: @alice.id, balance: true }, { player_id: @alice.id, topic: "market" } ], notices
  end

  test "a voided lead refreshes the removed leader's balance and the seller's market topic" do
    voided = Game::Market::LeadVoided.new(data: { listing_id: 1, seller_id: @alice.id, leader_id: @bob.id, released: 30_000 })

    assert_includes PlayerStream::EVENTS, Game::Market::LeadVoided
    assert_equal [ { player_id: @bob.id, balance: true }, { player_id: @alice.id, topic: "market" } ], PlayerStream.notices(voided)
  end

  test "a withdrawn listing tells its seller and its leader when present" do
    withdrawn = ->(leader_id) { Game::Market::ListingWithdrawn.new(data: { listing_id: 1, seller_id: @alice.id, leader_id:, released: 0 }) }

    assert_equal [ @alice.id, @bob.id ], PlayerStream.notices(withdrawn.(@bob.id)).map { it[:player_id] }
    assert_equal [ @alice.id ], PlayerStream.notices(withdrawn.(nil)).map { it[:player_id] }
  end
end
