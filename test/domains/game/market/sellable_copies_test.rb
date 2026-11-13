require "test_helper"
require_relative "../../../support/holdings"

class Game::Market::SellableCopiesTest < ActiveSupport::TestCase
  include Holdings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
  end

  test "it lists one row per edition with a free copy, rarest first, with the card to draw" do
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 2, reserved: 1)

    copies = Game::Market::SellableCopies.call(@player, locale: :en)

    assert_equal [ "#{@rare.card.slug}:#{@rare.season.number}", "#{@common.card.slug}:#{@common.season.number}" ], copies.map(&:ref)
    assert_equal [ 1, 3 ], copies.map(&:free)
    assert_equal [ 1, 0 ], copies.map(&:reserved)
    assert_equal [ "rare", "common" ], copies.map { it.card.rarity.to_s }
  end

  test "a fully reserved edition is left out" do
    hold(@player, @common.id, 1, reserved: 1)

    assert_empty Game::Market::SellableCopies.call(@player, locale: :en)
  end

  test "an edition without a rarity is left out" do
    hold(@player, @common.id, 1)
    @common.update_columns(rarity: nil)

    assert_empty Game::Market::SellableCopies.call(@player, locale: :en)
  end

  test "an only copy that is listed is no longer sellable" do
    hold(@player, @rare.id, 1, reserved: 1)

    assert_empty Game::Market::SellableCopies.call(@player, locale: :en)
  end

  test "a card slug keeps only that card's editions" do
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 2)

    copies = Game::Market::SellableCopies.call(@player, locale: :en, card_slug: @rare.card.slug)

    assert_equal [ "#{@rare.card.slug}:#{@rare.season.number}" ], copies.map(&:ref)
  end

  test "another player's copies are not listed" do
    hold(accounts_players(:moderator), @common.id, 2)

    assert_empty Game::Market::SellableCopies.call(@player, locale: :en)
  end

  test "the filter and the page are read in the database, with the count of what the filter keeps" do
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 1)
    hold(@player, catalog_card_seasons(:legendary_card_one).id, 2)
    rarities = ->(**options) { Game::Market::SellableCopies.call(@player, locale: :en, **options).map { it.card.rarity.to_s } }

    assert_equal [ "rare" ], rarities.(offset: 1, limit: 1)
    assert_equal [ "legendary", "common" ], rarities.(filter: Game::Market::CopyFilter.new(doubles: true))
    assert_equal [ "common" ], rarities.(filter: Game::Market::CopyFilter.new(query: "soldier", rarities: %w[common]))
    assert_equal [ "rare" ], rarities.(refs: [ "#{@rare.card.slug}:#{@rare.season.number}" ])
    assert_equal 2, Game::Market::SellableCopies.count(@player, locale: :en, filter: Game::Market::CopyFilter.new(doubles: true))
  end

  test "the search ignores accents" do
    hold(@player, @common.id, 1)
    Catalog::CardText.where(card_id: @common.card_id).update_all(title: "Éclair")

    assert_equal 1, Game::Market::SellableCopies.call(@player, locale: :en, filter: Game::Market::CopyFilter.new(query: "eclair")).size
  end

  test "a row carries no database id" do
    hold(@player, @rare.id, 1)

    copy = Game::Market::SellableCopies.call(@player, locale: :en).first

    assert_equal %i[ref card free reserved], copy.to_h.keys
    assert_match(/\A[^:]+:\d+\z/, copy.ref)
  end
end
