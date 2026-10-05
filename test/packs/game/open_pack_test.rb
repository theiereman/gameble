require "test_helper"
require_relative "../../support/game_packs"

# Game::OpenPack (R4, AD-6, AD-7): the oldest available pack, its cards
# counted into the holdings, and every failure.
class Game::OpenPackTest < ActiveSupport::TestCase
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

  test "no_pack_available has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_predicate Game::OpenPack.failure_message(:no_pack_available), :present? }
    end
  end
end
