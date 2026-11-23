require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/decks"
require_relative "../support/live_duels"
require_relative "../support/duels"
require_relative "../support/market"

# GET /:locale/duels: the DUELS tab's root, the challenge block above the player's decks in creation order, each a link
# to its editor with its twelve covers, and the way to a new deck while fewer than five. GET /:locale/duels/:token: a
# duel's board, for the players holding its seats only.
class DuelsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Decks
  include LiveDuels
  include Duels
  include MarketSettings

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
      assert_select "[aria-hidden=true]", "Mes decks · 0 / 3"
      assert_select ".visually-hidden", "Mes decks, 0 sur 3"
    end
    assert_select ".duel-decks__list .deck-row", 0
    assert_select "a.deck-new[href='/fr/duels/decks/new'] .deck-new__label", "Nouveau deck"
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

    assert_select "#duel-decks-heading [aria-hidden=true]", "Mes decks · 2 / 3"
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
    assert_select "a.deck-new[href='/fr/duels/decks/new']", 1
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

  test "three decks and no slot bought: no way to a fourth, the line that says so instead" do
    3.times { |index| create_deck("Deck #{index + 1}") }
    sign_in(@player)

    get duels_path(locale: :en)

    assert_equal 3, rows.size
    assert_select "#duel-decks-heading [aria-hidden=true]", "My decks · 3 / 3"
    assert_select "#duel-decks-heading .visually-hidden", "My decks, 3 of 3"
    assert_select "a[href='/en/duels/decks/new']", 0
    assert_select ".duel-decks__full", "Five decks at most: delete one to make another."
  end

  test "three decks with a slot price: + NEW DECK opens the slot purchase, described by its price; five decks: the line again" do
    open_market!
    3.times { |index| create_deck("Deck #{index + 1}") }
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".duel-decks[data-controller='row-focus purchase-dialog'] dialog#slot-purchase-dialog"
    assert_select "a.deck-new[href='/en/slots/decks/4'][aria-haspopup=dialog][aria-describedby=deck-slot-price][data-action='purchase-dialog#open']"
    assert_select "#duel-decks-heading + p#deck-slot-price", text: /\AFree slots taken: the next one costs\s+1,000\s*\.\z/
    assert_select ".duel-decks__full", 0

    Game::CapacitySlot.create!(player_id: @player.id, kind: "deck", bought: 2)
    2.times { |index| create_deck("Deck #{index + 4}") }
    get duels_path(locale: :en)

    assert_select "a.deck-new, #deck-slot-price, #slot-purchase-dialog", 0
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

  test "the sheet holds the complete decks and the friends open to friends as radios, the first of each chosen" do
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
    assert_select ".duel-lobby button[aria-haspopup=dialog][data-dialog-opener-dialog-value=duel-sheet]", "Challenge a friend"
    assert_select "dialog#duel-sheet:not([open]) .modal__title", "Challenge a friend"
    assert_select "dialog#duel-sheet form[action='/en/duels/challenges'][method=post]" do
      assert_select "input[type=radio][name=deck]", 2
      assert_select "input[type=radio][name=deck][value='#{deck.token}'][checked]:not([aria-disabled])"
      assert_select "input[type=radio][name=deck][aria-disabled=true]:not([checked])", 1
      assert_select "input[type=radio][name=friend]", 1
      assert_select "input[type=radio][name=friend][value='#{hugo.token}'][checked]"
      assert_select "label .duel-choice__name", "Hugo"
      assert_select "button[type=submit]:not([aria-disabled])", "Challenge"
    end
  end

  test "a draft radio is aria-disabled and says in its name how many cards it holds and why it cannot play" do
    complete_deck(@player, "Lea")
    create_deck("Brouillon")
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select "#duel-sheet label.duel-choice--disabled", text: /Brouillon\s+0 \/ 12\s+A draft cannot play: it needs 12 cards\./
  end

  test "the last deck used is chosen when it is still complete" do
    first = complete_deck(@player, "Lea")
    second = complete_deck(@player, "Max")
    hugo = accounts_players(:moderator)
    befriend(@player, hugo)
    complete_deck(hugo, "Hugo")
    duel = Game::ChallengeFriend.new.call(player: @player, friend: hugo, deck_token: second.token).value!
    Game::CancelChallenge.new.call(player: @player, token: duel.token).value!
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select "#duel-sheet input[name=deck][value='#{second.token}'][checked]"
    assert_select "#duel-sheet input[name=deck][value='#{first.token}'][checked]", 0
  end

  test "a friend row in a duel is aria-disabled and its name carries the duel" do
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    Game::DuelSeat.create!(duel: Game::Duel.create!, role: "challenger", player_id: hugo.id, status: "seated")
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select "#duel-sheet input[name=friend][value='#{hugo.token}'][aria-disabled=true]:not([checked])"
    assert_select "#duel-sheet label.duel-choice--disabled", text: /Hugo, in a duel/
  end

  test "the sheet disables its challenge with the reason it cannot be sent, and opens for a linked friend" do
    sign_in(@player)

    get duels_path(locale: :en)
    assert_select "#duel-sheet button[type=submit][aria-disabled=true][aria-describedby=duel-sheet-reason]", "Challenge"
    assert_select "#duel-sheet #duel-sheet-reason", "You need a complete 12-card deck to challenge."

    complete_deck(@player, "Lea")
    get duels_path(locale: :en)
    assert_select "#duel-sheet #duel-sheet-reason", "Add friends to challenge them."

    @player.update_columns(visibility: "private")
    get duels_path(locale: :fr)
    assert_select "#duel-sheet #duel-sheet-reason", "Vos duels sont fermés tant que votre profil est privé."
    assert_select "#duel-sheet[open]", 0
  end

  test "a friend token in the link opens the sheet on that friend, an unknown one is ignored" do
    hugo = accounts_players(:moderator)
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    sign_in(@player)

    get duels_path(locale: :en, friend: hugo.token)
    assert_select "dialog#duel-sheet[open] input[name=friend][value='#{hugo.token}'][checked]"

    get duels_path(locale: :en, friend: "nobody")
    assert_select "dialog#duel-sheet input[name=friend][value='#{hugo.token}'][checked]"
    assert_select "dialog#duel-sheet[open]", 0
  end

  test "a friend who is gone is greyed in the open sheet with its inline line" do
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    sign_in(@player)
    hugo.update_columns(reachable_until: 1.minute.ago)

    post duel_challenges_path(locale: :en), params: { friend: hugo.token, deck: deck_token_of(@player) }
    follow_redirect!

    assert_select "dialog#duel-sheet[open] input[name=friend][value='#{hugo.token}'][aria-disabled=true]:not([checked])"
    assert_select "#duel-sheet .duel-choice__note", "Hugo is no longer available."
    assert_select ".toast--alert", 0
  end

  test "every page of a signed-in player holds the received challenge as a dialog with its move number" do
    hugo = accounts_players(:moderator)
    hugo.update!(persona_name: "Hugo")
    befriend(@player, hugo)
    complete_deck(hugo, "Hugo")
    deck = complete_deck(@player, "Lea")
    duel = Game::ChallengeFriend.new.call(player: hugo, friend: @player, deck_token: deck_token_of(hugo)).value!
    sign_in(@player)

    [ duels_path(locale: :en), friends_path(locale: :en) ].each do |path|
      get path

      assert_select "#duel-received dialog#duel-dialog[data-controller=duel-received] .modal__title", "Hugo challenges you to a duel."
      assert_select "#duel-dialog form[action='/en/duels/#{duel.token}/acceptance'][method=post]" do
        assert_select "input[type=hidden][name=move_number][value='0']"
        assert_select "input[type=radio][name=deck][value='#{deck.token}'][checked]"
        assert_select "button[type=submit]", "Accept"
      end
      assert_select "#duel-dialog form[action='/en/duels/#{duel.token}/refusal'] button", "Refuse"
      assert_select "#duel-dialog .duel-clock"
    end
  end

  test "a received challenge without a complete deck offers to refuse only" do
    hugo = accounts_players(:moderator)
    befriend(@player, hugo)
    complete_deck(hugo, "Hugo")
    duel = Game::ChallengeFriend.new.call(player: hugo, friend: @player, deck_token: deck_token_of(hugo)).value!
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select "#duel-dialog form[action='/en/duels/#{duel.token}/acceptance']", 0
    assert_select "#duel-dialog .duel-lobby__line", "A draft cannot play: it needs 12 cards."
    assert_select "#duel-dialog form[action='/en/duels/#{duel.token}/refusal'] button", "Refuse"
  end

  test "no dialog is rendered when no challenge is held" do
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select "#duel-received"
    assert_select "#duel-received dialog", 0
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
    assert_select "#duel-sheet .duel-sheet__waiting[tabindex='-1']" do
      assert_select "form[action='/en/duels/#{duel.token}/cancellation'] button", "Cancel"
      assert_select ".duel-clock"
    end
    assert_select "#duel-sheet form[action='/en/duels/challenges']", 0

    Game::AcceptChallenge.new.call(player: hugo, token: duel.token, deck_token: deck_token_of(hugo), move_number: 0).value!
    get duels_path(locale: :en)
    assert_select "#duel-seated .duel-lobby__line", "Duel in progress against Hugo."
    assert_select "#duel-seated a[href='/en/duels/#{duel.token}']", "Resume"
    assert_select "#duel-sheet button[type=submit][aria-disabled=true]"
    assert_select "#duel-sheet #duel-sheet-reason", "You already have a duel in progress."
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

  test "a seat's board: the opponent, the round, the score, both decks, its own hand alone, no tab bar, no back and no style" do
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
    assert_select ".tab-bar", 0
    assert_select ".top-bar__bridge, .top-bar__previous, .top-bar__phone-back", 0
    assert_select "turbo-cable-stream-source[channel=DuelSeatChannel]", 1
    assert_select "section.duel.page.page--regular[data-controller=duel] #duel-board[data-duel-target=board][data-move-number='1']"
    assert_select "#duel-status[role=status][aria-live=polite]", 1
    assert_select "#duel-board #duel-status", 0
    assert_select "#duel-board .duel-board__opponent", "Hugo"
    assert_select "#duel-round-heading[tabindex='-1']" do
      assert_select ".duel-board__round[aria-hidden=true]", "Round 1 / 10"
      assert_select ".visually-hidden", "Round 1 of 10"
    end
    assert_select "#duel-board .duel-board__figure[aria-hidden=true]", "0 – 0"
    assert_select "#duel-board .visually-hidden", "0 to 0"
    assert_select "#duel-their-deck .duel-deck__card", 12
    assert_select "#duel-my-deck .duel-deck__card", 12
    hand = css_select("#duel-my-deck [data-card]").text
    rules.hand(:challenger).each { assert_includes hand, Catalog::CardText.where(card_id: card_of(it.card_season_id)).pick(:title) }
    assert_no_match(/Hugo card/, hand)
    assert_select(rules.caller == :challenger ? "form#duel-call" : "#duel-my-deck [data-card]", minimum: 1)
    assert_select "[style]", 0
    assert_select "#duel-board input[name=authenticity_token]", 0
  end

  def finished_duel(result, challenger: @player, opponent: accounts_players(:moderator), scores: [ 6, 4 ], ended_at: Time.current)
    duel = active_duel
    duel.assign_attributes(state: "finished", result:, ended_at:, challenger_score: scores.first, opponent_score: scores.last)
    duel.save!
    { "challenger" => challenger, "opponent" => opponent }.each do |role, player|
      Game::DuelSeat.create!(duel:, role:, player_id: player.id, status: "left")
    end
    duel
  end

  test "the record with the way to the rules, and the last results, each named by its outcome and score, opening its result" do
    accounts_players(:moderator).update!(persona_name: "Hugo")
    won = finished_duel("challenger", ended_at: 2.hours.ago)
    lost = finished_duel("challenger", challenger: accounts_players(:moderator), opponent: @player, ended_at: 1.hour.ago)
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".duel-record .duel-record__line", "Duels: 1 win, 1 loss, 0 draws"
    assert_select ".duel-record .duel-record__figure", 3
    assert_select ".duel-record a", 0
    assert_select ".duel-tutorial a.button.button--link[href='/en/how-it-works#how-it-works-duels']", "Detailed rules"
    assert_select "h2#duel-history-heading", "Recent duels"
    names = css_select(".duel-history__row .visually-hidden").map(&:text)
    assert_equal [ "Loss against Hugo, 4 to 6", "Win against Hugo, 6 to 4" ], names
    assert_equal [ "/en/duels/#{lost.token}", "/en/duels/#{won.token}" ], css_select(".duel-history__row").map { it["href"] }
    assert_select "[style]", 0

    get duels_path(locale: :fr)

    assert_select ".duel-record__line", "Duels : 1 victoire, 1 défaite, 0 égalité"
    assert_select ".duel-tutorial a.button--link", "Fonctionnement détaillé"
    assert_select ".duel-history__row .visually-hidden", "Défaite contre Hugo, 4 à 6"
  end

  test "no duel: a zero record and no recent duels group" do
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".duel-record__line", "Duels: 0 wins, 0 losses, 0 draws"
    assert_select ".duel-history", 0
  end

  test "the history keeps ten rows, and an opponent who left the game reads anonymous" do
    banned = accounts_players(:moderator)
    12.times { finished_duel("challenger", opponent: banned) }
    banned.update!(banned_at: Time.current)
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".duel-history__row", 10
    assert_select ".duel-history__row .visually-hidden", text: "Win against An anonymous player, 6 to 4", count: 10
    assert_select ".duel-history__row [aria-hidden=true] .player-name--anonymous", 10
  end

  test "a finished duel's result opens for its two seats and not for a third player" do
    hugo = accounts_players(:moderator)
    befriend(@player, hugo)
    complete_deck(@player, "Lea")
    complete_deck(hugo, "Hugo")
    duel = start_duel(@player, hugo)
    10.times { play_round(duel) }
    sign_in(accounts_players(:administrator))

    get duel_path(locale: :en, token: duel.token)

    assert_response :forbidden

    delete session_path(locale: :en)
    sign_in(hugo)
    get duel_path(locale: :en, token: duel.token)

    assert_response :success
    assert_select "#duel-result-heading"
    get duels_path(locale: :en)

    assert_select ".duel-history__row[href='/en/duels/#{duel.token}']", 1
  end
end
