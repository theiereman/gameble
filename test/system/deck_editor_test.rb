require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/decks"

# The deck editor: a new deck is created by its first change, every change saves at once, a second edition of a game
# and a thirteenth card are refused, a slot's button takes its card out, and a deleted deck frees its copies.
class DeckEditorTest < ApplicationSystemTestCase
  include SteamSignIn
  include Decks

  setup do
    @player = accounts_players(:player)
    @cards = ranked_cards(@player, 13, titles: Array.new(13) { format("Game %02d", it + 1) })
    @second_edition = second_editions([ @cards.first ]).sole
    hold(@player, @second_edition)
    rank([ @second_edition ])
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def entry(card_season_id) = find(".deck-entry__toggle[data-ref='#{ref_of(card_season_id)}']")

  def assert_focused(ref)
    eventually("#{ref} should have the focus") { page.evaluate_script("document.activeElement.dataset.ref") == ref }
  end

  def assert_status(text) = assert_selector(".deck-editor__status", text:)

  test "a player fills a deck, names it, is refused a second edition and a thirteenth card, empties a slot and deletes the deck" do
    sign_in(@player)
    visit new_deck_path(locale: :en)

    @cards.first(12).each_with_index do |card, index|
      entry(card).click
      assert_status "Game #{format("%02d", index + 1)} added, #{index + 1} of 12"
    end
    assert_selector ".deck-editor__count", text: "12 / 12"
    eventually("the twelve cards should be saved") { Game::DeckCard.count == 12 }
    deck = Game::Deck.sole
    assert_current_path deck_path(locale: :en, token: deck.token)
    assert_equal 1, reserved_of(@player, @cards.first)

    fill_in "Deck name", with: "Vieux briscards"
    find("#deck-name").send_keys(:tab)
    assert_selector ".deck-editor__summary-name", text: "Vieux briscards"
    eventually("the name should be saved") { deck.reload.name == "Vieux briscards" }

    entry(@second_edition).click
    assert_status "This game is already in the deck."
    entry(@cards.last).click
    assert_status "The deck is full."
    assert_selector ".deck-entry__toggle[data-ref='#{ref_of(@cards.last)}'][aria-pressed=false]"

    find("button.deck-slot[aria-label='Remove Game 01 from the deck']").click
    assert_selector ".deck-slots__slot:first-child .deck-slot--empty"
    assert_selector ".deck-editor__count", text: "11 / 12"
    eventually("the next filled slot should take the focus") { page.evaluate_script("document.activeElement.getAttribute('aria-label')") == "Remove Game 02 from the deck" }
    eventually("the card should be taken out") { Game::DeckCard.count == 11 }
    assert_equal 0, reserved_of(@player, @cards.first)

    click_on "Delete the deck"
    within("#delete-deck") do
      assert_selector "#delete-deck-title", text: /\Adelete the deck "vieux briscards"\?\z/i
      click_on "Delete"
    end

    assert_current_path new_deck_path(locale: :en)
    assert_text "Deck deleted."
    assert_no_selector ".deck-entry__reserved"
    assert_no_selector ".deck-entry__toggle[aria-disabled=true]"
    assert_selector ".deck-entry__toggle[aria-pressed=false]", count: 14
    assert_equal 0, Game::Holding.where(player_id: @player.id).sum(:reserved)
  end

  test "the collection is one tab stop moved by the arrow keys; a card added or taken out keeps the focus" do
    sign_in(@player)
    visit new_deck_path(locale: :en)

    assert_selector ".deck-entry__toggle[tabindex='0']", count: 1
    entry(@cards.first).send_keys(:right)
    assert_focused(ref_of(@second_edition))
    page.send_keys(:right)
    assert_focused(ref_of(@cards.second))
    assert_selector ".deck-entry__toggle[tabindex='0']", count: 1

    page.send_keys(:enter)
    assert_status "Game 02 added, 1 of 12"
    assert_selector ".deck-entry__toggle[data-ref='#{ref_of(@cards.second)}'][aria-pressed=true]"
    assert_focused(ref_of(@cards.second))
    assert_match(/, in the deck\z/, entry(@cards.second)["aria-label"])

    page.send_keys(:enter)
    assert_status "Game 02 removed, 0 of 12"
    assert_focused(ref_of(@cards.second))
  end
end
