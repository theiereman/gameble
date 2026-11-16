require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/decks"
require_relative "../support/live_duels"

# GET /:locale/duels: the DUELS tab's root, the challenge block above the player's decks in creation order, each a link
# to its editor with its twelve covers, and the way to a new deck while fewer than five. GET /:locale/duels/:token: a
# duel's board, for the players holding its seats only.
class DuelsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Decks
  include LiveDuels

  setup do
    @player = accounts_players(:player)
  end

  def create_deck(name) = Game::CreateDeck.new.call(player: @player, name:).value!

  def fill(deck, card_season_ids)
    card_season_ids.each.with_index(1) do |card_season_id, slot|
      Game::DeckCard.create!(deck:, slot:, card_season_id:, card_id: Catalog::CardSeason.where(id: card_season_id).pick(:card_id))
    end
  end

  def rows = css_select("ul.duel-decks__list > li > a.deck-row")

  test "a visitor is sent to the landing" do
    get duels_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
  end

  test "no deck: the heading and the way to a new deck alone" do
    sign_in(@player)

    get duels_path(locale: :fr)

    assert_response :success
    assert_select "title", /Duels/
    assert_select "main h1", "Duels"
    assert_select "h2#duel-decks-heading[tabindex='-1']" do
      assert_select "[aria-hidden=true]", "Mes decks · 0 / 5"
      assert_select ".visually-hidden", "Mes decks, 0 sur 5"
    end
    assert_select ".duel-decks__list", 0
    assert_select "a.button.button--link[href='/fr/duels/decks/new']", "+ Nouveau deck"
    assert_select ".duel-decks__full", 0
    assert_select ".duel-decks[data-row-focus-landing-value]", 0
  end

  test "the decks in creation order, a full one and a draft, each named, its covers hidden and lazy, the empty slots dashed" do
    ids = published_cards(12).last
    full = create_deck("Vieux briscards")
    draft = create_deck("Brouillon")
    fill(full, ids)
    fill(draft, ids.first(9))
    sign_in(@player)

    get duels_path(locale: :fr)

    assert_select "#duel-decks-heading [aria-hidden=true]", "Mes decks · 2 / 5"
    assert_equal [ "/fr/duels/decks/#{full.token}", "/fr/duels/decks/#{draft.token}" ], rows.pluck("href")
    assert_equal [ "Vieux briscards, 12 cartes", "Brouillon, brouillon, 9 sur 12" ],
      rows.map { |row| row.css(".deck-row__name, .deck-row__head > .visually-hidden").map(&:text).join }
    assert_equal [ nil, "9 / 12" ], rows.map { it.at_css(".deck-row__count[aria-hidden=true]")&.text }
    rows.each do |row|
      assert row.at_css(".deck-row__covers[aria-hidden=true]")
      assert_equal 12, row.css(".deck-row__cover").size
    end
    assert_equal 12, rows.first.css("img.deck-row__art[alt=''][loading=lazy]").size
    assert_equal [ 9, 3 ], [ rows.last.css("img.deck-row__art").size, rows.last.css(".deck-row__cover--empty").size ]
    assert_select "a.button--link[href='/fr/duels/decks/new']", 1
  end

  test "a filled slot whose card cannot be shown is drawn as an empty cell, still counted" do
    ids = published_cards(12).last
    fill(create_deck("Vieux briscards"), ids)
    Catalog::CardSeason.where(id: ids.first).update_all(rarity: nil)
    sign_in(@player)

    get duels_path(locale: :en)

    row = rows.sole
    assert_equal [ 11, 1 ], [ row.css("img.deck-row__art").size, row.css(".deck-row__cover--empty").size ]
    assert_empty row.css("img:not([src])")
    assert_nil row.at_css(".deck-row__count")
  end

  test "five decks: no way to a sixth, the line that says so instead" do
    5.times { |index| create_deck("Deck #{index + 1}") }
    sign_in(@player)

    get duels_path(locale: :en)

    assert_equal 5, rows.size
    assert_select "#duel-decks-heading .visually-hidden", "My decks, 5 of 5"
    assert_select "a[href='/en/duels/decks/new']", 0
    assert_select ".duel-decks__full", "Five decks at most: delete one to make another."
  end

  test "the DUELS tab's root: top-level with the player menu, the tab current as the page, no style and no ids" do
    deck = create_deck("Vieux briscards")
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".top-bar--top-level", 1
    assert_select ".top-bar__phone-back", 0
    assert_select ".top-bar__title", "Duels"
    assert_select ".tab-bar a.tab-bar__tab[href='/en/duels'][aria-current=page]", 1
    assert_select ".tab-bar a.tab-bar__tab[aria-current]", 1
    assert_select "[style]", 0
    assert_no_match(/\b#{deck.id}\b/, css_select("main").to_html.scan(/(?:href|id|data-[\w-]+)="[^"]*"/).join(" "))
  end

  test "a player sees only their own decks" do
    Game::CreateDeck.new.call(player: accounts_players(:moderator), name: "Pas le mien").value!
    sign_in(@player)

    get duels_path(locale: :en)

    assert_empty rows
  end

  test "the challenge form: the complete decks and the friends open to friends as radios, the first of each chosen" do
    deck = complete_deck(@player, "Lea")
    create_deck("Brouillon")
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    befriend(@player, accounts_players(:administrator))
    accounts_players(:administrator).update_columns(visibility: "private")
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".duels[data-controller=live-refresh][data-live-refresh-signal-value=duels-updated]"
    assert_select "#duel-lobby-heading", "Challenge a friend"
    assert_select "form#duel-challenge[action='/en/duels/challenges'][method=post]" do
      assert_select "input[type=radio][name=deck]", 1
      assert_select "input[type=radio][name=deck][value='#{deck.token}'][checked]"
      assert_select "input[type=radio][name=friend]", 1
      assert_select "input[type=radio][name=friend][value='#{hugo.token}'][checked]"
      assert_select "label .player-name", "Hugo"
      assert_select "button[type=submit]", "Challenge"
    end
  end

  test "the challenge form gives way to the line that says why it cannot be sent" do
    sign_in(@player)

    get duels_path(locale: :en)
    assert_select ".duel-lobby__line", "You need a complete 12-card deck to challenge."

    complete_deck(@player, "Lea")
    get duels_path(locale: :en)
    assert_select ".duel-lobby__line", "Add friends to challenge them."

    @player.update_columns(visibility: "private")
    get duels_path(locale: :fr)
    assert_select ".duel-lobby__line", "Vos duels sont fermés tant que votre profil est privé."
    assert_select "form#duel-challenge", 0
  end

  test "a received challenge offers the complete decks and its move number to accept it" do
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    complete_deck(hugo, "Hugo")
    deck = complete_deck(@player, "Lea")
    duel = Game::ChallengeFriend.new.call(player: hugo, friend: @player, deck_token: deck_token_of(hugo)).value!
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select "#duel-received .duel-lobby__line", "Hugo challenges you to a duel."
    assert_select "#duel-received form[action='/en/duels/#{duel.token}/acceptance'][method=post]" do
      assert_select "input[type=hidden][name=move_number][value='0']"
      assert_select "input[type=radio][name=deck][value='#{deck.token}'][checked]"
      assert_select "button[type=submit]", "Accept"
    end
  end

  test "the challenger waits for the answer, then is led back to the duel in progress" do
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    complete_deck(hugo, "Hugo")
    duel = Game::ChallengeFriend.new.call(player: @player, friend: hugo, deck_token: deck_token_of(@player)).value!
    sign_in(@player)

    get duels_path(locale: :en)
    assert_select "#duel-seated .duel-lobby__line", "Waiting for Hugo's answer…"
    assert_select "form#duel-challenge", 0

    Game::AcceptChallenge.new.call(player: hugo, token: duel.token, deck_token: deck_token_of(hugo), move_number: 0).value!
    get duels_path(locale: :en)
    assert_select "#duel-seated .duel-lobby__line", "Duel in progress against Hugo."
    assert_select "#duel-seated a[href='/en/duels/#{duel.token}']", "Resume"
  end

  test "a duel is shown to the players holding its seats only" do
    hugo = accounts_players(:moderator)
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    complete_deck(hugo, "Hugo")
    duel = start_duel(@player, hugo)

    get duel_path(locale: :en, token: duel.token)
    assert_redirected_to home_path(locale: :en)

    sign_in(accounts_players(:administrator))
    get duel_path(locale: :en, token: duel.token)
    assert_response :forbidden

    get duel_path(locale: :en, token: "Zz" * 12)
    assert_response :forbidden
  end

  test "a seat's board: the opponent, the round, the score, both decks, its own hand alone, and no style" do
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    complete_deck(hugo, "Hugo")
    duel = start_duel(@player, hugo)
    rules = rules_of(Game::Duel.find(duel.id))
    sign_in(@player)

    get duel_path(locale: :en, token: duel.token)

    assert_response :success
    assert_select ".top-bar__title", "Duel"
    assert_select "turbo-cable-stream-source[channel=DuelSeatChannel]", 1
    assert_select "section.duel.page.page--regular[data-controller=duel] #duel-board[data-duel-target=board][data-move-number='1']"
    assert_select "#duel-board .duel-board__opponent", "Hugo"
    assert_select "#duel-board .duel-board__round", "Round 1 / 10"
    assert_select "#duel-board .duel-board__figure", "0 – 0"
    assert_select "#duel-their-deck li", 12
    assert_select "#duel-my-deck li", 12
    hand = css_select("#duel-hand").text
    rules.hand(:challenger).each { assert_includes hand, Catalog::CardText.where(card_id: card_of(it.card_season_id)).pick(:title) }
    assert_no_match(/Hugo card/, hand)
    assert_select(rules.caller == :challenger ? "form#duel-call" : "#duel-hand ul li", minimum: 1)
    assert_select "[style]", 0
    assert_select "#duel-board input[name=authenticity_token]", 0
  end
end
