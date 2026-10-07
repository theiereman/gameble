require "test_helper"
require_relative "../../support/game_packs"

# First discoveries and set completions (AD-9, AD-10, story 6.7): the first
# pull of a card in its season is recorded once and enters the feed as a
# discovery; a player who holds every card of a set for the first time, by
# an opening or an accepted trade, gets one Game::SetCompleted.
class Game::FirstDiscoveryAndSetCompletionTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @common, @uncommon, @rare, @portal, @legendary = fixture_tier_ids
    @valve = catalog_sets(:valve_one).id
  end

  # The fixture season's cards were all discovered (fixtures): forgets
  # `ids` so the next opening of them is a first discovery.
  def undiscover(*ids) = Game::FirstDiscovery.where(card_season_id: ids).delete_all

  def open_pack(player, cards)
    create_pack(player, cards:)
    Game::OpenPack.new.call(player:).value!
  end

  def entries(pack) = Game::FeedEntry.where(pack_id: pack.id).order(:position).pluck(:position, :kind, :notable)

  # The valve set gains `ids` beside portal_one.
  def add_to_valve(*ids)
    Catalog::SetMembership.insert_all!(ids.each_with_index.map { |id, index| { set_id: @valve, card_season_id: id, position: index + 2 } })
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity) = Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)

  def trade(offer:, request:, from: @player, to: @other)
    trade = Game::ProposeTrade.new.call(player: from, recipient: to, offer:, request:).value!
    Game::AcceptTrade.new.call(player: to, trade_id: trade.id).value!
  end

  # First discoveries

  test "a card nobody had pulled is recorded once, published after the opening and enters the feed as a discovery" do
    undiscover(@common)

    pack = open_pack(@player, [ @common, @uncommon, @rare, @uncommon, @common ])

    discovery = Game::FirstDiscovery.find_by!(card_season_id: @common)
    assert_equal [ @player.id, pack.id, pack.opened_at ], [ discovery.player_id, discovery.pack_id, discovery.discovered_at ]
    assert_equal [ Game::PackOpened, Game::CardDiscovered ], game_events(@player).last(2).map(&:class)
    assert_equal({ player_id: @player.id, card_season_id: @common, pack_id: pack.id }, game_events(@player, Game::CardDiscovered).sole.data)
    assert_equal [ [ 0, "discovery", true ] ], entries(pack), "the first copy only; no filler beside a discovery"
  end

  test "a card already discovered records nothing, publishes nothing and stays a pull" do
    pack = open_pack(@player, [ @legendary ] * 5)

    assert_equal accounts_players(:banned).id, Game::FirstDiscovery.find_by!(card_season_id: @legendary).player_id
    assert_empty game_events(@player, Game::CardDiscovered)
    assert_equal [ "pull" ], Game::FeedEntry.where(pack_id: pack.id).distinct.pluck(:kind)
  end

  test "a notable card discovered is one discovery entry, the other notable cards stay pulls" do
    undiscover(@legendary)

    pack = open_pack(@player, [ @common, @legendary, @portal, @legendary, @common ])

    assert_equal [ [ 1, "discovery", true ], [ 2, "pull", true ], [ 3, "pull", true ] ], entries(pack)
    assert_equal [ @legendary ], game_events(@player, Game::CardDiscovered).map { it.data[:card_season_id] }
  end

  test "several cards discovered by one opening: one row and one event each, ascending" do
    undiscover(@common, @rare)

    pack = open_pack(@player, [ @rare, @common, @rare, @common, @uncommon ])

    assert_equal [ @common, @rare ], game_events(@player, Game::CardDiscovered).map { it.data[:card_season_id] }
    assert_equal [ pack.id ], Game::FirstDiscovery.where(card_season_id: [ @common, @rare ]).distinct.pluck(:pack_id)
    assert_equal [ [ 0, "discovery", true ], [ 1, "discovery", true ] ], entries(pack)
  end

  test "the next player to pull a discovered card makes no discovery" do
    undiscover(@rare)
    open_pack(@player, [ @rare ] * 5)

    pack = open_pack(@other, [ @rare ] * 5)

    assert_equal @player.id, Game::FirstDiscovery.find_by!(card_season_id: @rare).player_id
    assert_empty game_events(@other, Game::CardDiscovered)
    assert_equal [ [ 0, "pull", false ] ], entries(pack)
  end

  test "a replayed opening discovers nothing more" do
    undiscover(@common)
    create_pack(@player, cards: [ @common ] * 5)
    key = SecureRandom.uuid
    Game::OpenPack.new.call(player: @player, idempotency_key: key).value!

    assert_no_difference -> { Game::FirstDiscovery.count + game_events(@player).size } do
      Game::OpenPack.new.call(player: @player, idempotency_key: key).value!
    end
  end

  test "discoveries show under the whole feed and DÉCOUVERTES, not under the pulls" do
    undiscover(@common)
    open_pack(@player, [ @common ] * 5)

    assert_equal [ "discovery" ], Game::FeedEntries.call(nil).map { it.entry.kind }
    assert_equal [ "discovery" ], Game::FeedEntries.call(nil, kind: "discovery").map { it.entry.kind }
    assert_empty Game::FeedEntries.call(nil, kind: "pull")
  end

  test "the opening's budget: three statements more, whatever its cards discover or complete" do
    add_to_valve(@common, @rare)
    undiscover(@common, @uncommon, @rare)
    statements = []
    counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/game_first_discoveries|game_set_completions/) }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      open_pack(@player, [ @common, @uncommon, @rare, @portal, @legendary ])
    end

    assert_equal 3, statements.size, statements.join("\n")
    assert_equal [ @valve ], Game::SetCompletion.where(player_id: @player.id).pluck(:set_id)
    assert_equal 3, game_events(@player, Game::CardDiscovered).size
  end

  # Set completions

  test "an opening that completes a set records it and publishes SetCompleted once, after the opening" do
    open_pack(@player, [ @portal ] * 5)

    assert_equal [ @valve ], Game::SetCompletion.where(player_id: @player.id).pluck(:set_id)
    assert_equal [ Game::PackOpened, Game::SetCompleted ], game_events(@player).last(2).map(&:class)
    assert_equal({ player_id: @player.id, set_id: @valve }, game_events(@player, Game::SetCompleted).sole.data)

    open_pack(@player, [ @portal ] * 5)

    assert_equal 1, game_events(@player, Game::SetCompleted).size
    assert_equal 1, Game::SetCompletion.where(player_id: @player.id).count
  end

  test "a set completes only with its last missing card, held with copies left" do
    add_to_valve(@common, @rare)
    hold(@player, @rare, 0)

    open_pack(@player, [ @portal ] * 5)
    open_pack(@player, [ @common ] * 5)
    assert_empty game_events(@player, Game::SetCompleted), "rare_card_one is held with no copy left"

    open_pack(@player, [ @rare, @uncommon, @uncommon, @uncommon, @uncommon ])
    assert_equal [ @valve ], game_events(@player, Game::SetCompleted).map { it.data[:set_id] }
  end

  test "an opening touching no set records no completion" do
    open_pack(@player, [ @legendary ] * 5)

    assert_empty Game::SetCompletion.all
    assert_empty game_events(@player, Game::SetCompleted)
  end

  test "each player's completion is their own" do
    open_pack(@player, [ @portal ] * 5)
    open_pack(@other, [ @portal ] * 5)

    assert_equal [ @player.id, @other.id ].sort, Game::SetCompletion.where(set_id: @valve).pluck(:player_id).sort
    assert_equal 1, game_events(@other, Game::SetCompleted).size
  end

  test "an accepted trade that completes a set publishes SetCompleted for the player who gains the card, once" do
    befriend(@player, @other)
    hold(@player, @portal, 2)
    hold(@other, @rare, 1)

    trade(offer: { @portal => 1 }, request: { @rare => 1 })

    assert_equal [ @valve ], game_events(@other, Game::SetCompleted).map { it.data[:set_id] }
    assert_equal [ Game::TradeAccepted, Game::SetCompleted ], Rails.configuration.event_store.read.to_a.last(2).map(&:class)
    assert_empty game_events(@player, Game::SetCompleted), "the proposer gained a card in no set"
    assert_equal [ [ @other.id, @valve ] ], Game::SetCompletion.pluck(:player_id, :set_id)
  end

  test "a card traded away and gained back completes nothing new" do
    befriend(@player, @other)
    hold(@player, @portal, 1)
    hold(@other, @rare, 2)
    trade(offer: { @portal => 1 }, request: { @rare => 1 })
    trade(from: @other, to: @player, offer: { @portal => 1 }, request: { @rare => 1 })

    trade(offer: { @portal => 1 }, request: { @rare => 1 })

    assert_equal 1, game_events(@other, Game::SetCompleted).size
    assert_equal 1, game_events(@player, Game::SetCompleted).size, "the player's first completion, on gaining it back"
  end
end
