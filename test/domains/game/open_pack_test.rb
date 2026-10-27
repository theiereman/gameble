require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"

# Game::OpenPack (R4, AD-6, AD-7): the oldest available pack, its cards
# counted into the holdings, and every failure.
class Game::OpenPackTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GamePacks

  setup { @player = accounts_players(:player) }

  def open = Game::OpenPack.new.call(player: @player)

  def holdings
    Game::Holding.where(player_id: @player.id).order(:card_season_id).pluck(:card_season_id, :quantity, :reserved)
  end

  test "opening takes the oldest available pack, credits its cards, publishes PackOpened and leaves nine" do
    Game::FillBank.new.call(player: @player).value!
    packs = Game::Pack.where(player_id: @player.id)
    oldest = packs.order(:available_at, :id).first

    result = open

    assert result.success?
    pack = result.value!
    assert_equal oldest, pack
    assert_predicate pack.reload, :opened?
    assert_equal 9, Game::BankSummary.call(@player)[:available]
    expected = pack.card_season_ids.tally.sort.map { |id, count| [ id, count, 0 ] }
    assert_equal expected, holdings
    events = game_events(@player, Game::PackOpened)
    assert_equal [ { player_id: @player.id, pack_id: pack.id } ], events.map(&:data)
  end

  test "the order is availability time, then id" do
    later = create_pack(@player, available_at: 1.minute.ago)
    first = create_pack(@player, available_at: 2.minutes.ago)
    tie = create_pack(@player, available_at: first.available_at)

    assert_equal [ first, tie, later ], Array.new(3) { open.value! }
  end

  test "a card twice in a pack adds two; a card already held is incremented in its row" do
    portal, legendary = catalog_card_seasons(:portal_one).id, catalog_card_seasons(:legendary_card_one).id
    common = catalog_card_seasons(:common_card_one).id
    create_pack(@player, cards: [ legendary, portal, common, portal, common ], available_at: 2.minutes.ago)
    create_pack(@player, cards: [ portal, common, common, common, legendary ])

    open.value!
    assert_equal [ [ common, 2, 0 ], [ portal, 2, 0 ], [ legendary, 1, 0 ] ].sort, holdings

    open.value!
    assert_equal [ [ common, 5, 0 ], [ portal, 3, 0 ], [ legendary, 2, 0 ] ].sort, holdings
    assert_equal 3, Game::Holding.where(player_id: @player.id).count
  end

  test "every credited holding, new or raised, is gained at the opening (AD-26); an untouched one keeps its time" do
    portal, common, legendary = %i[portal_one common_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    earlier = Time.zone.parse("2026-10-01 08:00:00.250000")
    Game::Holding.create!(player_id: @player.id, card_season_id: portal, quantity: 1, last_gained_at: earlier)
    Game::Holding.create!(player_id: @player.id, card_season_id: legendary, quantity: 1, last_gained_at: earlier)
    create_pack(@player, cards: [ portal, common, common, portal, portal ])

    pack = open.value!

    gained = Game::Holding.where(player_id: @player.id).to_h { [ it.card_season_id, it.last_gained_at ] }
    assert_equal pack.reload.opened_at, gained.fetch(portal)
    assert_equal pack.opened_at, gained.fetch(common)
    assert_equal earlier, gained.fetch(legendary)
  end

  test "moving reserved copies leaves last_gained_at as it is" do
    portal = catalog_card_seasons(:portal_one).id
    create_pack(@player, cards: Array.new(5, portal))
    open.value!
    holding = Game::Holding.find_by!(player_id: @player.id, card_season_id: portal)

    assert_no_changes -> { holding.reload.last_gained_at } do
      Game::Holding.where(id: holding.id).update_all(reserved: 2, updated_at: 1.minute.from_now)
    end
  end

  test "with every pack opened, opening fails and changes nothing" do
    create_pack(@player, opened_at: 1.hour.ago)

    assert_no_changes -> { [ Game::Pack.where(player_id: @player.id).pluck(:opened_at), holdings, game_events(@player).size ] } do
      assert_equal :no_pack_available, open.failure
    end
  end

  test "a pack available tomorrow is not opened" do
    future = create_pack(@player, available_at: 1.day.from_now)

    assert_equal :no_pack_available, open.failure
    assert_nil future.reload.opened_at
    assert_empty holdings
  end

  test "a bonus pack is counted and opened in order like the others" do
    regular = create_pack(@player, available_at: 1.minute.ago)
    bonus = create_pack(@player, available_at: 2.minutes.ago, kind: :bonus)

    assert_equal 2, Game::BankSummary.call(@player)[:available]
    assert_equal bonus, open.value!
    assert_equal regular, open.value!
  end

  test "another player's packs are not opened" do
    create_pack(accounts_players(:moderator))

    assert_equal :no_pack_available, open.failure
  end

  test "a missing or banned player fails with player_required" do
    [ nil, accounts_players(:banned) ].each do |player|
      assert_equal :player_required, Game::OpenPack.new.call(player:).failure
    end
  end

  test "a pack banked before a new season opens with cards of that season, each in its old card's tier" do
    stale = create_pack(@player, cards: fixture_tier_ids)
    stale_bonus = create_pack(@player, kind: :bonus, cards: fixture_tier_ids.last(3), available_at: 2.minutes.ago)
    season = seed_card_seasons(distinct_scores(150))
    Catalog::PublishSeason.new.call(number: season.number).value!

    [ [ stale_bonus, [ 3, 4, 5 ] ], [ stale, [ 1, 2, 3, 4, 5 ] ] ].each do |pack, tiers|
      assert_equal pack, open.value!
      pack.reload
      assert_equal season.id, pack.season_id
      assert_equal tiers, Catalog::CardSeasonTiers.call(pack.card_season_ids).values_at(*pack.card_season_ids)
      assert_equal [ season.id ], Catalog::CardSeason.where(id: pack.card_season_ids).distinct.pluck(:season_id)
    end
    assert_equal [ season.id ], Catalog::CardSeason.where(id: holdings.map(&:first)).distinct.pluck(:season_id)
  end

  test "a pack of the published season opens with the cards it was drawn with" do
    pack = create_pack(@player, cards: fixture_tier_ids)

    open.value!

    assert_equal fixture_tier_ids, pack.reload.card_season_ids
    assert_equal catalog_seasons(:one).id, pack.season_id
  end

  test "no_pack_available has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_predicate Game::OpenPack.failure_message(:no_pack_available), :present? }
    end
  end

  # --- The opening exchange's key (AD-23) ---------------------------------

  KEY = "0f8e2c4a-6b1d-4e3f-9a7c-5d2b8e1f3a6c".freeze

  def open_with(key, player: @player) = Game::OpenPack.new.call(player:, idempotency_key: key)

  # Everything an opening writes for the player.
  def written
    [ Game::Pack.where(player_id: @player.id).order(:id).pluck(:id, :opened_at, :idempotency_key, :card_back), holdings, game_events(@player).size ]
  end

  test "an opening with a key stores the key and the standard card back" do
    create_pack(@player)

    pack = open_with(KEY).value!

    assert_equal KEY, pack.reload.idempotency_key
    assert_equal "standard", pack.card_back
    assert_equal "standard", pack.card_back_key
  end

  test "the same key again returns the same pack and writes nothing, even with no pack left" do
    Game::FillBank.new.call(player: @player).value!
    first = open_with(KEY).value!

    assert_no_changes -> { written } do
      assert_equal first, open_with(KEY).value!
      assert_equal first, open_with(KEY.upcase).value!
    end

    9.times { open.value! }
    Game::Pack.where(player_id: @player.id).unopened.delete_all
    assert_equal :no_pack_available, open.failure
    assert_no_changes -> { written } do
      assert_equal first, open_with(KEY).value!
    end
    assert_equal 1, game_events(@player, Game::PackOpened).count { it.data[:pack_id] == first.id }
  end

  test "a malformed key is refused before any write" do
    create_pack(@player)

    [ "", "not-a-uuid", "#{KEY}x", KEY.delete("-"), 42 ].each do |key|
      assert_no_changes -> { written } do
        assert_equal :invalid_idempotency_key, open_with(key).failure, key.inspect
      end
    end
  end

  test "another player's key is a new key: it opens this player's pack" do
    moderator = accounts_players(:moderator)
    create_pack(moderator)
    theirs = open_with(KEY, player: moderator).value!
    mine = create_pack(@player)

    assert_equal mine, open_with(KEY).value!
    assert_not_equal theirs, mine
    assert_equal KEY, mine.reload.idempotency_key
  end

  test "without a key, the pack opens as before, keeps no key and the standard back" do
    create_pack(@player)

    pack = open.value!.reload

    assert_nil pack.idempotency_key
    assert_equal "standard", pack.card_back
  end

  test "a pack opened before the back was kept reads as standard" do
    pack = create_pack(@player, opened_at: 1.minute.ago)

    assert_nil pack.card_back
    assert_equal Game::CardBacks::STANDARD, pack.card_back_key
  end

  test "replay? is true only for a well-formed key a pack of the player's carries" do
    create_pack(@player)
    open_with(KEY).value!

    assert Game::OpenPack.replay?(@player, KEY)
    assert Game::OpenPack.replay?(@player, KEY.upcase)
    assert_not Game::OpenPack.replay?(accounts_players(:moderator), KEY)
    assert_not Game::OpenPack.replay?(nil, KEY)
    assert_not Game::OpenPack.replay?(@player, SecureRandom.uuid)
    assert_not Game::OpenPack.replay?(@player, "not-a-uuid")
    assert_not Game::OpenPack.replay?(@player, nil)
  end

  test "invalid_idempotency_key has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_predicate Game::OpenPack.failure_message(:invalid_idempotency_key), :present? }
    end
  end
end
