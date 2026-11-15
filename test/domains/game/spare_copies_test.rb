require "test_helper"
require_relative "../../support/decks"

# A spare is a free copy of a game, over its editions with a rarity, beyond the one its holder keeps. The trade
# suggestions and the collection report count it this way, a deck-blocked copy being reserved.
class Game::SpareCopiesTest < ActiveSupport::TestCase
  include Decks

  setup do
    @player = accounts_players(:player)
    @lea = accounts_players(:moderator)
    low, high = [ @player.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    @deck = Game::CreateDeck.new.call(player: @lea).value!
  end

  def put_in_deck(card_season_id) = Game::AddCardToDeck.new.call(player: @lea, token: @deck.token, card_season_id:).value!

  def suggested(card_ids)
    wanted = card_ids.to_h { [ it, [ 1 ] ] }
    declined = Game::TradeSuggestions::DeclinedByFriend.call(@player, [ @lea.id ])
    Game::TradeSuggestions::Spares.from_friends(@player, [ @lea.id ], wanted, declined, Time.current).fetch(@lea.id, [])
  end

  test "three copies with one in a deck leave one spare, for the suggestions and the report alike" do
    card = ranked_cards(@lea, 1, quantity: 3).sole
    put_in_deck(card)

    assert_equal({ [ @lea.id, card_of(card) ] => 1 }, Game::SpareCopies.by_game([ @lea.id ]))
    assert_equal 1, Game::SpareCopies.total(@lea)
    assert_equal [ card_of(card) ], suggested([ card_of(card) ]).map(&:card_id)
  end

  test "two copies with one in a deck leave none, and the game is not suggested" do
    card = ranked_cards(@lea, 1, quantity: 2).sole
    put_in_deck(card)

    assert_equal({}, Game::SpareCopies.by_game([ @lea.id ]))
    assert_equal 0, Game::SpareCopies.total(@lea)
    assert_empty suggested([ card_of(card) ])
  end

  test "free copies add up over a game's editions; an edition with no rarity never counts" do
    first, other = ranked_cards(@lea, 2)
    put_in_deck(first)
    hold(@lea, second_editions([ first ]).sole, 2)
    unrated = second_editions([ other ]).sole
    Catalog::CardSeason.where(id: unrated).update_all(rarity: nil)
    hold(@lea, unrated, 3)

    assert_equal({ [ @lea.id, card_of(first) ] => 1 }, Game::SpareCopies.by_game([ @lea.id ]))
    assert_equal({}, Game::SpareCopies.by_game([ @lea.id ], card_ids: [ card_of(other) ]))
    assert_equal 1, Game::SpareCopies.total(@lea)
  end

  test "a rated and an unrated free copy of a wanted game make no spare, and the game is not suggested" do
    card = ranked_cards(@lea, 1).sole
    unrated = second_editions([ card ]).sole
    Catalog::CardSeason.where(id: unrated).update_all(rarity: nil)
    hold(@lea, unrated)

    assert_empty suggested([ card_of(card) ])
  end

  test "a visitor or nothing asked costs no query" do
    assert_queries_count(0) do
      assert_equal 0, Game::SpareCopies.total(nil)
      assert_equal({}, Game::SpareCopies.by_game([]))
      assert_equal({}, Game::SpareCopies.by_game([ @lea.id ], card_ids: []))
    end
  end
end
