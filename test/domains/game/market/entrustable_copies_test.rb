require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"

class Game::Market::EntrustableCopiesTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!
  end

  test "it lists the unreserved copies of editions with a rarity, most valuable first, with their value" do
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 2, reserved: 1)
    hold(@player, catalog_card_seasons(:uncommon_card_one).id, 1, reserved: 1)

    copies = Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en)

    assert_equal [ :rare, :common ], copies.map(&:rarity)
    assert_equal [ 1, 3 ], copies.map(&:free)
    assert_equal [ 2, 3 ], copies.map(&:owned)
    assert_equal [ 5_000, 1_000 ], copies.map(&:value)
    assert_equal [ "#{@rare.card.slug}:#{@rare.season.number}", "#{@common.card.slug}:#{@common.season.number}" ], copies.map(&:ref)
  end

  test "a card slug keeps only that card's editions" do
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 2)

    copies = Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en, card_slug: @rare.card.slug)

    assert_equal [ "#{@rare.card.slug}:#{@rare.season.number}" ], copies.map(&:ref)
    assert_equal 2, Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en, card_slug: nil).size
  end

  test "the filter keeps a title search, rarities and editions held twice or more, and the count follows it" do
    uncommon = catalog_card_seasons(:uncommon_card_one)
    hold(@player, @common.id, 3)
    hold(@player, @rare.id, 1)
    hold(@player, uncommon.id, 2, reserved: 1)
    copies = ->(filter) { Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :fr, filter:).map(&:rarity) }

    assert_equal [ :common ], copies.(Game::Market::CopyFilter.new(query: "PLOMB"))
    assert_equal [ :common ], copies.(Game::Market::CopyFilter.new(query: "tin soldier"))
    assert_equal [ :rare, :common ], copies.(Game::Market::CopyFilter.new(rarities: %w[rare common mythic]))
    assert_equal [ :uncommon, :common ], copies.(Game::Market::CopyFilter.new(doubles: true))
    assert_equal 2, Game::Market::EntrustableCopies.count(@player, locale: :fr, filter: Game::Market::CopyFilter.new(doubles: true))
    assert_equal 3, Game::Market::EntrustableCopies.count(@player, locale: :fr)
  end

  test "the search ignores accents and case on both sides" do
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)
    Catalog::CardText.where(card_id: @common.card_id).update_all(title: "Éclair")
    found = ->(query) { Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :fr, filter: Game::Market::CopyFilter.new(query:)).map(&:rarity) }

    assert_equal [ :common ], found.("eclair")
    assert_equal [ :common ], found.("ÉCLAIR")
    assert_equal [ :common ], found.("Ecla")
    assert_equal 1, Game::Market::EntrustableCopies.count(@player, locale: :fr, filter: Game::Market::CopyFilter.new(query: "éclair"))
  end

  test "a page holds the copies from its offset, in value order, and only its cards are drawn" do
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)
    hold(@player, catalog_card_seasons(:legendary_card_one).id, 1)

    page = Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en, offset: 1, limit: 1)

    assert_equal [ :rare ], page.map(&:rarity)
    assert_equal "Blue Depths", page.sole.card.title
    assert_nil Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en, cards: false).first.card
  end

  test "the value order follows the settings, then season, title and ref" do
    settings = open_market!(entrustment_common: 200_000)
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)

    assert_equal [ :common, :rare ], Game::Market::EntrustableCopies.call(@player, settings:, locale: :en).map(&:rarity)
  end

  test "refs keep only those editions" do
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)
    refs = [ "#{@common.card.slug}:#{@common.season.number}", "nothing:1" ]

    assert_equal [ refs.first ], Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en, refs:).map(&:ref)
    assert_empty Game::Market::EntrustableCopies.call(@player, settings: @settings, locale: :en, refs: [])
  end

  test "refs resolve to card-season ids, and an unknown ref is left out" do
    refs = [ "#{@rare.card.slug}:#{@rare.season.number}", "nothing:1", "malformed" ]

    assert_equal({ refs.first => @rare.id }, Game::Market::EntrustableCopies.resolve(refs))
  end
end
