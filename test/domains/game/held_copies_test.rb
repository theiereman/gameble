require "test_helper"
require_relative "../../support/holdings"

class Game::HeldCopiesTest < ActiveSupport::TestCase
  include Holdings
  setup do
    @player = accounts_players(:player)
    @portal, @common, @legendary = %i[portal_one common_card_one legendary_card_one].map { catalog_card_seasons(it).id }
  end

  def deck_card(player, card_season_id)
    deck = Game::Deck.create!(player_id: player.id, name: "Vieux briscards")
    Game::DeckCard.create!(deck_id: deck.id, card_season_id:, card_id: Catalog::CardSeason.find(card_season_id).card_id, slot: 1)
  end

  test "each card held, its copies, reserved and free, in one query" do
    hold(@player, @portal, 3, reserved: 1)
    hold(@player, @common, 2, reserved: 2)
    hold(@player, @legendary, 0)
    hold(accounts_players(:moderator), @legendary, 4)

    held = nil
    assert_queries_count(1) { held = Game::HeldCopies.call(@player) }

    assert_equal [ @portal, @common ].sort, held.keys
    assert_equal [ 3, 1, 2 ], held.fetch(@portal).then { [ it.quantity, it.reserved, it.free ] }
    assert_equal 0, held.fetch(@common).free
  end

  test "the player's own deck blocks a copy from friends' requests; another player's deck of the edition does not" do
    hold(@player, @portal, 2)
    hold(@player, @common, 1)
    deck_card(accounts_players(:player), @portal)
    deck_card(accounts_players(:moderator), @common)

    held = Game::HeldCopies.call(@player)

    assert_equal [ true, 1 ], held.fetch(@portal).then { [ it.in_deck, it.offerable ] }
    assert_equal [ false, 1 ], held.fetch(@common).then { [ it.in_deck, it.offerable ] }
  end

  test "another player can be asked about, a visitor holds nothing" do
    hold(accounts_players(:moderator), @legendary, 4)

    assert_equal [ @legendary ], Game::HeldCopies.call(accounts_players(:moderator)).keys
    assert_queries_count(0) { assert_equal({}, Game::HeldCopies.call(nil)) }
  end
end
