require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/counting_rate_limit"
require_relative "../support/decks"

# The deck editor's addresses: the editor of a new deck and of a deck by its token, the JSON saves of each change with
# their refusals, the deletion, the owner alone let in, and sixty changes a minute.
class DecksControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include CountingRateLimit
  include Decks

  setup do
    @player = accounts_players(:player)
  end

  def json = { as: :json }

  def create_deck(name: nil, player: @player) = Game::CreateDeck.new.call(player:, name:).value!

  def assert_refusal(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, response.parsed_body)
  end

  test "a visitor is sent to sign in, and refused a save" do
    get new_deck_path(locale: :en)
    assert_redirected_to home_path(locale: :en)

    post decks_path(locale: :en), params: { name: "Vieux" }, **json
    assert_response :unauthorized
    assert_equal 0, Game::Deck.count
  end

  test "a player's editor lists each owned edition with its trump, or why it cannot enter, and writes nothing" do
    ranked = ranked_cards(@player, 2, titles: [ "Quake", "Alone in the Dark" ])
    reserved = ranked_cards(@player, 1, titles: [ "Myst" ]).sole
    Game::Holding.where(player_id: @player.id, card_season_id: reserved).update_all(reserved: 1)
    _season, (unranked,) = published_cards(1)
    hold(@player, unranked)
    sign_in(@player)

    assert_no_difference -> { Game::Deck.count } do
      get new_deck_path(locale: :fr)
    end

    assert_response :success
    titles = css_select(".deck-entry__toggle .card__title").map(&:text)
    assert_equal [ "Alone in the Dark", "Myst", "Quake", "Seed 0" ], titles
    assert_select ".deck-entry__toggle[aria-disabled=true]", 2
    assert_select ".deck-entry__toggle[data-ref='#{ref_of(ranked.first)}'][aria-pressed=false]"
    assert_select ".deck-entry__reserved", "Réservée"
    assert_select ".deck-card__detail", "Stats lundi"
    assert_select ".deck-slots__slot .deck-slot--empty", 12
    assert_select ".deck-editor__delete[hidden]"
    assert_select "[data-deck-editor-target=entry][data-ref]", 4
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_no_match(/data-[a-z-]*id="\d+"/, response.body)
  end

  test "an edition whose only copy another deck blocks can still be chosen" do
    card = ranked_cards(@player, 1).sole
    Game::AddCardToDeck.new.call(player: @player, token: create_deck.token, card_season_id: card).value!
    assert_equal 1, reserved_of(@player, card)
    sign_in(@player)

    get new_deck_path(locale: :en)

    assert_select ".deck-entry__toggle[data-ref='#{ref_of(card)}']:not([aria-disabled])[aria-pressed=false]" do
      assert_select ".deck-entry__action", "Add"
      assert_select ".deck-entry__reserved", 0
    end
  end

  test "a deck's editor shows its cards in their slots, each a button taking it out" do
    card = ranked_cards(@player, 1, titles: [ "Quake" ]).sole
    deck = create_deck(name: "Vieux briscards")
    Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: card).value!
    sign_in(@player)

    get deck_path(locale: :en, token: deck.token)

    assert_response :success
    assert_select ".deck-slots__slot:first-child button.deck-slot__remove[aria-label=?]", "Remove Quake from the deck"
    assert_select ".deck-entry__toggle[aria-pressed=true][aria-label=?]", "Quake, S#{Catalog::Season.maximum(:number)}, Trump · #{trump_of(card)}, in the deck"
    assert_select "#deck-name[value=?]", "Vieux briscards"
    assert_select ".deck-editor__delete:not([hidden])"
    assert_select "form.delete-deck__form[action=?]", deck_path(locale: :en, token: deck.token)
  end

  test "the editor draws the deck's coverage, the sort and trump choices, and under each deck card the stats that moved since Monday" do
    _season, (unranked,) = published_cards(1)
    hold(@player, unranked)
    moved, steady = ranked_cards(@player, 2, titles: [ "Quake", "Myst" ])
    set_percentiles(moved, popularity: 62, release: 30, weekly: { popularity: 55, release: 40 })
    set_percentiles(steady, popularity: 95, weekly: { popularity: 99.1 })
    deck = create_deck
    [ moved, steady ].each { Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: it).value! }
    sign_in(@player)

    get deck_path(locale: :fr, token: deck.token)

    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_select ".deck-coverage__group--advantages .deck-coverage__line", 10
    assert_select ".deck-coverage__group--advantages .deck-coverage__line:not([hidden])", 0
    assert_select ".deck-coverage__group--advantages .deck-coverage__none:not([hidden])", "Aucun pour l'instant"
    assert_select ".deck-coverage__group--drawbacks .deck-coverage__line[data-call=popularity-high][hidden]"
    assert_select ".deck-coverage__group--drawbacks .deck-coverage__line[data-call=release-low]:not([hidden])" do
      assert_select "button.deck-coverage__gap[aria-label=?]", "Manque de cartes anciennes, trier la collection", text: "Manque de cartes"
    end
    assert_select "input.deck-collection__search[type=search][aria-label=?]", "Rechercher dans vos cartes"
    assert_select ".deck-entry .stat-bars .stat-bars__row", minimum: 5
    assert_select "select", 0
    assert_select ".deck-collection .sort__button", /\ATri : La plus populaire\z/
    assert_select ".deck-collection .sort__current", "La plus populaire"
    assert_select ".deck-collection .sort__option", 11
    assert_select ".deck-collection .sort__option[aria-current=true]", "La plus populaire"
    assert_select ".deck-collection .sort__option[href=?]", "#{deck_path(locale: :fr, token: deck.token)}?sort=release-low", text: "La plus ancienne"
    assert_select "fieldset.deck-collection__trumps legend.visually-hidden", "Atout"
    assert_equal %w[Toutes Popularité Note Sortie Découverte Circulation], css_select(".deck-collection__trumps .filter-chip__text").map(&:text)
    assert_select "input.filter-chip__box[type=radio][name=trump][value=all][checked]"
    assert_select ".deck-slots__slot:first-child" do
      assert_select ".deck-slot__moves[aria-hidden=true]", "▲ Pop. ▼ Sortie"
      assert_select "button.deck-slot__remove[aria-label=?]",
        "Retirer Quake du deck. Popularité en hausse\u202F: 62, contre 55 lundi dernier. Sortie en baisse\u202F: 30, contre 40 lundi dernier"
    end
    assert_select ".deck-slots__slot:nth-child(2) .deck-slot__moves", ""
    assert_select ".deck-slots__slot:nth-child(2) button.deck-slot__remove[aria-label=?]", "Retirer Myst du deck"
    entry = css_select(".deck-entry__toggle[data-ref='#{ref_of(moved)}']").sole
    assert_equal({ "popularity" => 62.0, "rating" => 50.0, "release" => 30.0, "discovery" => 50.0, "circulation" => 50.0 }, JSON.parse(entry["data-percentiles"]))
    assert_equal [ "release", "▲ Pop. ▼ Sortie" ], [ entry["data-trump"], entry["data-moves-text"] ]
    assert Game::DuelStat.where(card_season_id: unranked).where.not(trump_stat: nil).exists?
    unranked_entry = css_select(".deck-entry__toggle[data-ref='#{ref_of(unranked)}']").sole
    assert_equal [ Game::DuelStat::STATS.to_h { [ it.to_s, nil ] }, "" ], [ JSON.parse(unranked_entry["data-percentiles"]), unranked_entry["data-trump"] ]
    assert_select "[style]", 0
  end

  test "with five decks the new editor says so and shows no editor" do
    5.times { create_deck }
    sign_in(@player)

    get new_deck_path(locale: :fr)

    assert_select ".deck-editor__notice", "Cinq decks au plus : supprimez-en un pour en créer un autre."
    assert_select "#deck-editor", 0
  end

  test "each change saves in JSON: a deck created with its address, renamed, a card added then taken out, with the deck's coverage" do
    card = ranked_cards(@player, 1).sole
    set_percentiles(card, popularity: 95)
    sign_in(@player)

    post decks_path(locale: :en), params: { name: nil }, **json
    deck = Game::Deck.sole
    assert_equal({ "token" => deck.token, "url" => deck_path(locale: :en, token: deck.token), "name" => "Deck 1" }, response.parsed_body)

    patch deck_path(locale: :en, token: deck.token), params: { name: "Vieux" }, **json
    assert_equal({ "name" => "Vieux" }, response.parsed_body)

    post deck_cards_path(locale: :en, token: deck.token), params: { ref: ref_of(card) }, **json
    assert_equal({ "slot" => 1, "count" => 1 }, response.parsed_body.except("coverage"))
    coverage = response.parsed_body["coverage"]
    assert_equal 10, coverage.size
    assert_equal [ { "call" => "popularity-high", "best" => 95, "gap" => false, "many" => false }, { "call" => "popularity-low", "best" => 5, "gap" => true, "many" => false },
      { "call" => "rating-high", "best" => 50, "gap" => true, "many" => false } ], coverage.first(3)

    delete deck_cards_path(locale: :en, token: deck.token), params: { ref: ref_of(card) }, **json
    assert_equal({ "slot" => 1, "count" => 0 }, response.parsed_body.except("coverage"))
    assert response.parsed_body["coverage"].all? { it["best"].nil? && it["gap"] }
    assert_equal 0, reserved_of(@player, card)
  end

  test "a refused change answers 422 with its code and message in the page's language" do
    first = ranked_cards(@player, 1).sole
    second = second_editions([ first ]).sole
    hold(@player, second)
    rank([ second ])
    deck = create_deck(name: "Vieux")
    create_deck(name: "Confidentiels")
    Game::AddCardToDeck.new.call(player: @player, token: deck.token, card_season_id: first).value!
    sign_in(@player)

    post deck_cards_path(locale: :fr, token: deck.token), params: { ref: ref_of(second) }, **json
    assert_refusal(:unprocessable_content, "game_already_in_deck", "Ce jeu est déjà dans le deck.")

    post deck_cards_path(locale: :en, token: deck.token), params: { ref: ref_of(second) }, **json
    assert_refusal(:unprocessable_content, "game_already_in_deck", "This game is already in the deck.")

    patch deck_path(locale: :fr, token: deck.token), params: { name: "confidentiels" }, **json
    assert_refusal(:unprocessable_content, "deck_name_taken", "Vous avez déjà un deck de ce nom.")

    post deck_cards_path(locale: :en, token: deck.token), params: { ref: "nowhere:9" }, **json
    assert_refusal(:unprocessable_content, "card_not_owned", "You do not own this card.")
  end

  test "a token no deck holds is refused as not found, in JSON, and not found in HTML" do
    sign_in(@player)

    patch deck_path(locale: :en, token: "1" * 24), params: { name: "Vieux" }, **json
    assert_refusal(:unprocessable_content, "deck_not_found", "This deck cannot be found.")

    get deck_path(locale: :en, token: "1" * 24)
    assert_response :not_found
  end

  test "another player's deck is forbidden to every address" do
    deck = create_deck(player: accounts_players(:moderator))
    sign_in(@player)

    get deck_path(locale: :en, token: deck.token)
    assert_response :forbidden

    patch deck_path(locale: :en, token: deck.token), params: { name: "Mien" }, **json
    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.dig("error", "code")

    post deck_cards_path(locale: :en, token: deck.token), params: { ref: "portal:1" }, **json
    assert_response :forbidden

    delete deck_cards_path(locale: :en, token: deck.token), params: { ref: "portal:1" }, **json
    assert_response :forbidden

    delete deck_path(locale: :en, token: deck.token)
    assert_response :forbidden
    assert Game::Deck.exists?(deck.id)
  end

  test "a deletion lands on Duels with a toast and the focus on the deck list's heading" do
    deck = create_deck
    sign_in(@player)

    delete deck_path(locale: :fr, token: deck.token)

    assert_redirected_to duels_path(locale: :fr)
    assert_response :see_other
    assert_equal "Deck supprimé.", flash[:notice]
    assert_not Game::Deck.exists?(deck.id)

    follow_redirect!
    assert_select ".toast", /Deck supprimé\./
    assert_select ".duel-decks[data-controller=row-focus][data-row-focus-landing-value='']"
    assert_select "#duel-decks-heading[tabindex='-1'][data-row-focus-target=heading]"

    get duels_path(locale: :fr)
    assert_select ".duel-decks[data-row-focus-landing-value]", 0
  end

  test "the deck editor belongs to the DUELS tab and leads back to Duels" do
    deck = create_deck
    sign_in(@player)

    [ new_deck_path(locale: :fr), deck_path(locale: :fr, token: deck.token) ].each do |path|
      get path
      assert_select ".tab-bar a.tab-bar__tab[href='/fr/duels'][aria-current=true]", 1, path
      assert_select ".tab-bar a.tab-bar__tab[aria-current]", 1, path
      back = css_select(".top-bar__start > a.top-bar__phone-back").sole
      assert_equal [ "/fr/duels", "Duels" ], [ back["href"], back.at_css(".button__label").text ]
    end
  end

  test "changes to a deck and to its cards share sixty a minute, the sixty-first answered 429 in JSON" do
    card = ranked_cards(@player, 1).sole
    deck = create_deck
    sign_in(@player)
    throttled = "Trop de changements en une minute. Réessayez dans un instant."

    with_counting_rate_limit(DecksController) do
      with_counting_rate_limit(DeckCardsController) do
        30.times { |index| patch deck_path(locale: :fr, token: deck.token), params: { name: "Nom #{index}" }, **json }
        15.times do
          post deck_cards_path(locale: :fr, token: deck.token), params: { ref: ref_of(card) }, **json
          delete deck_cards_path(locale: :fr, token: deck.token), params: { ref: ref_of(card) }, **json
        end
        assert_response :success

        post deck_cards_path(locale: :fr, token: deck.token), params: { ref: ref_of(card) }, **json
        assert_refusal(:too_many_requests, "throttled", throttled)
        patch deck_path(locale: :fr, token: deck.token), params: { name: "Trop" }, **json
        assert_refusal(:too_many_requests, "throttled", throttled)
        assert_equal "Nom 29", deck.reload.name
        assert_equal 0, Game::DeckCard.count
      end
    end
  end

  private
    def trump_of(card_season_id)
      I18n.t("duel_stats.names.#{Game::DuelProfiles.call([ card_season_id ]).fetch(card_season_id).trump_stat}", locale: :en)
    end
end
