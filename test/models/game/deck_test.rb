require "test_helper"

# What the database refuses of a deck even when its operations are bypassed: a name of 1 to 24 characters unique to the
# player whatever its case, twelve slots, one card per slot and one edition of a game per deck.
class Game::DeckTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @deck = Game::Deck.create!(player_id: @player.id, name: "Vieux briscards")
    @portal = catalog_card_seasons(:portal_one)
  end

  def refused(error = ActiveRecord::StatementInvalid, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end

  def insert_card(card_season: @portal, slot: 1, card_id: card_season.card_id, deck: @deck)
    Game::DeckCard.insert_all!([ { deck_id: deck.id, card_season_id: card_season.id, card_id:, slot: } ])
  end

  test "a name is 1 to 24 characters, unique to the player whatever its case" do
    refused(ActiveRecord::CheckViolation) { Game::Deck.create!(player_id: @player.id, name: "") }
    refused(ActiveRecord::CheckViolation) { Game::Deck.create!(player_id: @player.id, name: "a" * 25) }
    refused(ActiveRecord::RecordNotUnique) { Game::Deck.create!(player_id: @player.id, name: "VIEUX BRISCARDS") }

    assert Game::Deck.create!(player_id: accounts_players(:moderator).id, name: "Vieux briscards").persisted?
  end

  test "a slot is 1 to 12, holds one card, and a game is in a deck once" do
    refused(ActiveRecord::CheckViolation) { insert_card(slot: 0) }
    refused(ActiveRecord::CheckViolation) { insert_card(slot: 13) }
    insert_card(slot: 12)

    refused(ActiveRecord::RecordNotUnique) { insert_card(card_season: catalog_card_seasons(:common_card_one), slot: 12) }
    refused(ActiveRecord::RecordNotUnique) { insert_card(slot: 3) }
  end

  test "a deck's cards go with it" do
    insert_card

    Game::Deck.where(id: @deck.id).delete_all

    assert_equal 0, Game::DeckCard.count
  end
end
