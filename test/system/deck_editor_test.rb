require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/decks"

# The deck editor: a new deck is created by its first change, every change saves at once, a second edition of a game
# and a thirteenth card are refused, a slot's button takes its card out, a deleted deck frees its copies and lands on Duels,
# a coverage gap sorts the collection, the search narrows it and a page of cards shows more on request.
class DeckEditorTest < ApplicationSystemTestCase
  include SteamSignIn
  include Decks

  LIST = "[data-deck-collection-target='list']".freeze

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

  def entry(card_season_id) = find("#{LIST} .deck-entry__toggle[data-ref='#{ref_of(card_season_id)}']")

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
    assert_selector ".deck-editor__summary-name", text: "Vieux briscards", visible: :all
    eventually("the name should be saved") { deck.reload.name == "Vieux briscards" }

    entry(@second_edition).click
    assert_status "This game is already in the deck."
    entry(@cards.last).click
    assert_status "The deck is full."
    assert_selector "#{LIST} .deck-entry__toggle[data-ref='#{ref_of(@cards.last)}'][aria-pressed=false]"

    find(".deck-slots__slot:first-child button.deck-slot").click
    assert_selector ".deck-slot__remove button", count: 1
    find("#deck-search").click
    assert_no_selector ".deck-slot__remove button"
    find(".deck-slots__slot:first-child button.deck-slot").click
    find(".deck-slot__remove button[aria-label='Remove Game 01 from the deck']").click
    assert_selector ".deck-slots__slot:first-child .deck-slot--empty"
    assert_selector ".deck-editor__count", text: "11 / 12"
    eventually("the next filled slot should take the focus") { page.evaluate_script("document.activeElement.closest('li')?.dataset.ref") == ref_of(@cards.second) }
    eventually("the card should be taken out") { Game::DeckCard.count == 11 }
    assert_equal 0, reserved_of(@player, @cards.first)

    click_on "Delete the deck"
    within("#delete-deck") do
      assert_selector "#delete-deck-title", text: /\Adelete the deck "vieux briscards"\?\z/i
      click_on "Delete"
    end

    assert_current_path duels_path(locale: :en)
    assert_text "Deck deleted."
    assert_no_selector ".deck-row"
    eventually("the deck list's heading should have the focus") { page.evaluate_script("document.activeElement.id") == "duel-decks-heading" }

    visit new_deck_path(locale: :en)
    assert_no_selector "#{LIST} .deck-entry__reserved"
    assert_no_selector "#{LIST} .deck-entry__toggle[aria-disabled=true]"
    assert_selector "#{LIST} .deck-entry__toggle[aria-pressed=false]", count: 14
    assert_equal 0, Game::Holding.where(player_id: @player.id).sum(:reserved)
  end

  test "a card dragged out of the deck is taken out, and one dropped back inside stays" do
    deck = Game::CreateDeck.new.call(player: @player).value!
    @cards.first(2).each { Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: it).value! }
    sign_in(@player)
    visit deck_path(locale: :en, token: deck.token)

    first_slot = find(".deck-slots__slot:first-child button.deck-slot")
    page.driver.browser.action.move_to(first_slot.native).click_and_hold.move_to(find(".deck-slots__slot:nth-child(2) button.deck-slot").native).release.perform
    assert_selector ".deck-editor__count", text: "2 / 12"

    page.driver.browser.action.move_to(first_slot.native).click_and_hold.move_to(find("#deck-search").native).release.perform
    assert_selector ".deck-editor__count", text: "1 / 12"
    eventually("the card should be taken out") { Game::DeckCard.count == 1 }
  end

  test "a card of the deck opens its details sheet from the button revealed by a click" do
    deck = Game::CreateDeck.new.call(player: @player).value!
    Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: @cards.first).value!
    sign_in(@player)
    visit deck_path(locale: :en, token: deck.token)

    find(".deck-slots__slot:first-child button.deck-slot").click
    click_on "Details"

    within("#deck-card-info") do
      assert_selector ".deck-info__name", text: "Game 01"
      assert_selector ".deck-info__card .deck-card"
      assert_link "Full card page", href: /\/cards\/.+\/seasons\/\d+/
    end
  end

  test "the save button waits for the changes on their way, then goes back to Duels" do
    sign_in(@player)
    visit new_deck_path(locale: :en)

    entry(@cards.first).click
    click_on "Save"

    assert_current_path duels_path(locale: :en)
    assert_equal 1, Game::DeckCard.count
  end

  test "the collection is one tab stop moved by the arrow keys; a card added or taken out keeps the focus" do
    sign_in(@player)
    visit new_deck_path(locale: :en)

    assert_selector "#{LIST} .deck-entry__toggle[tabindex='0']", count: 1
    entry(@cards.first).send_keys(:right)
    assert_focused(ref_of(@second_edition))
    page.send_keys(:right)
    assert_focused(ref_of(@cards.second))
    assert_selector "#{LIST} .deck-entry__toggle[tabindex='0']", count: 1

    page.send_keys(:enter)
    assert_status "Game 02 added, 1 of 12"
    assert_selector "#{LIST} .deck-entry__toggle[data-ref='#{ref_of(@cards.second)}'][aria-pressed=true]"
    assert_focused(ref_of(@cards.second))
    assert_match(/, in the deck\z/, entry(@cards.second)["aria-label"])

    page.send_keys(:enter)
    assert_status "Game 02 removed, 0 of 12"
    assert_focused(ref_of(@cards.second))
  end

  test "a gap in the coverage sorts the collection by its call, and a card that moved shows its arrow" do
    [ *@cards, @second_edition ].each { set_percentiles(it) }
    set_percentiles(@cards.first, popularity: 62, weekly: { popularity: 55 })
    oldest = @cards[5]
    set_percentiles(oldest, release: 3)
    deck = Game::CreateDeck.new.call(player: @player).value!
    @cards.first(3).each { Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: it).value! }
    sign_in(@player)
    visit deck_path(locale: :en, token: deck.token)

    assert_selector ".deck-slots__slot:first-child .deck-slot__moves", text: "▲ Pop."
    find(".deck-coverage__line[data-call='release-low'] .deck-coverage__gap").click
    assert_status "Collection sorted: Oldest"
    assert_selector "#{LIST} > li:first-child .deck-entry__toggle[data-ref='#{ref_of(oldest)}']"
    assert_selector ".deck-collection .sort__current", text: /\AOldest\z/i
    assert_selector ".deck-collection .sort__option[aria-current='true']", text: "Oldest", visible: :all
    eventually("the gap should keep the focus") { page.evaluate_script("document.activeElement.closest('[data-call]')?.dataset.call") == "release-low" }
  end

  test "the search narrows the collection by title, and the rest of a long collection shows on request" do
    extra = ranked_cards(@player, 14, titles: Array.new(14) { format("Extra %02d", it + 1) })
    sign_in(@player)
    visit deck_path(locale: :en, token: Game::CreateDeck.new.call(player: @player).value!.token)

    assert_selector "#{LIST} .deck-entry:not([hidden])", count: 24
    assert_selector "[data-deck-collection-target='recommended'] .deck-entry", count: 12
    click_on "Show more cards"
    assert_selector "#{LIST} .deck-entry:not([hidden])", count: 28
    assert_no_selector ".deck-collection__more:not([hidden])"

    fill_in "deck-search", with: "extra 01"
    assert_selector "#{LIST} .deck-entry:not([hidden])", count: 1
    fill_in "deck-search", with: "zzzz"
    assert_selector ".deck-collection__empty", text: "No card matches."
    assert_equal 14, extra.size
  end
end
