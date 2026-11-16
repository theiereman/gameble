require "test_helper"
require_relative "../../support/decks"

# A duel freezes a deck as its editions in season order then card number, each with the values of its duel profile.
class Game::DuelSnapshotTest < ActiveSupport::TestCase
  include Decks

  setup do
    @player = accounts_players(:player)
    @deck = Game::Deck.create!(player_id: @player.id, name: "Two seasons")
  end

  def fill(card_season_ids)
    Game::DeckCard.insert_all!(card_season_ids.each_with_index.map do |card_season_id, index|
      { deck_id: @deck.id, card_season_id:, card_id: card_of(card_season_id), slot: index + 1 }
    end)
  end

  test "a twelve-card deck over two seasons is frozen in season then card order, with its duel profiles, and survives the jsonb round trip" do
    first = ranked_cards(@player, 6)
    second = ranked_cards(@player, 6)
    fill((second + first).reverse)

    cards = Game::DuelSnapshot.call(@deck)

    assert_equal first + second, ids(cards)
    assert_equal [ *1..6, *1..6 ], cards.map(&:number)
    assert_equal [ 1 ] * 12, cards.map(&:rarity)
    profiles = Game::DuelProfiles.call(first + second)
    cards.each do |card|
      assert_equal card_of(card.card_season_id), card.card_id
      profiles.fetch(card.card_season_id).stats.each do |stat|
        assert_equal [ stat.value, stat.percentile, stat.median_distance ], card.stat(stat.name).to_h.values_at(:value, :percentile, :median_distance)
      end
    end
    assert cards.all? { it.stat(:discovery).value.present? }

    duel = Game::Duel.create!(challenger_cards: cards.map(&:to_snapshot))
    assert_equal cards, Game::Duel.find(duel.id).cards(:challenger)
  end

  test "a deck card without a duel profile cannot be frozen" do
    ranked = ranked_cards(@player, 1)
    _season, unranked = published_cards(1)
    fill(ranked + unranked)

    assert_raises(KeyError) { Game::DuelSnapshot.call(@deck) }
  end

  private
    def ids(cards) = cards.map(&:card_season_id)
end
