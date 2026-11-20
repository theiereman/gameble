require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/counting_rate_limit"
require_relative "../support/decks"
require_relative "../support/market"

# A copy a deck blocks, on the screens that count free copies: its owner sees which decks hold it and frees it there,
# through one form that takes the edition out of every deck; a friend sees the copy as absent and cannot ask for it.
class DeckBlockedCopiesTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include CountingRateLimit
  include Decks
  include MarketSettings

  def sign_in_origin = "/fr"

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @player.update!(persona_name: "Hugo")
    @friend.update!(persona_name: "Lea")
    low, high = [ @player.id, @friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def deck(player, name) = Game::CreateDeck.new.call(player:, name:).value!

  def put_in(deck, card_season_id, player: @player)
    Game::AddCardToDeck.new.call(player:, token: deck.token, card_season_id:).value!
  end

  def key_of(card_season_id) = ref_of(card_season_id).sub(":", "--s")

  def dialog_id(card_season_id) = "deck-removal-#{key_of(card_season_id)}"

  test "a friend's deck-blocked copy is unavailable in the picker, with no tag nor deck name, and cannot be asked for" do
    lone, pair = ranked_cards(@friend, 2, titles: [ "Portal", "Hades" ])
    Game::Holding.where(player_id: @friend.id, card_season_id: pair).update_all(quantity: 2)
    their_deck = deck(@friend, "Vieux briscards")
    [ lone, pair ].each { put_in(their_deck, it, player: @friend) }
    sign_in(@player)

    get new_trade_path(locale: :fr, friend: @friend.token)

    assert_response :success
    assert_select ".trade-pick[data-side='friend'][data-key='#{key_of(lone)}'][data-max='0']" do
      assert_select ".trade-pick__toggle[aria-disabled='true']"
      assert_select ".trade-pick__reserved", 0
      assert_select ".deck-holding", 0
    end
    assert_select ".trade-pick[data-side='friend'][data-key='#{key_of(pair)}'][data-max='1'][data-copies='1']"
    assert_no_match(/Vieux briscards/, response.body)

    assert_no_difference -> { Game::Trade.count } do
      post trades_path(locale: :fr), params: { friend: @friend.token, take: { key_of(lone) => "1" } }
    end
    assert_equal Game::Operation.failure_message(:request_exceeds_holdings, locale: :fr), flash[:alert]
  end

  test "the owner's picker tags a decked card, names its decks and opens its removal dialog" do
    card = ranked_cards(@player, 1, titles: [ "Portal" ]).sole
    first = deck(@player, "Vieux briscards")
    second = deck(@player, "Nouveaux venus")
    [ first, second ].each { put_in(it, card) }
    sign_in(@player)

    get new_trade_path(locale: :fr, friend: @friend.token)

    assert_select ".trade-pick[data-side='own'][data-key='#{key_of(card)}'][data-max='0']" do
      assert_select ".trade-pick__reserved", "Dans un deck"
      assert_select ".trade-pick__toggle[aria-label*=?]", "dans un deck : Vieux briscards, Nouveaux venus"
      assert_no_match(/réservé ailleurs/, css_select(".trade-pick__toggle").sole["aria-label"])
      assert_select ".deck-holding__names", "Dans : Vieux briscards, Nouveaux venus"
      assert_select "button[data-controller='dialog-opener'][data-dialog-opener-dialog-value=?][aria-label=?]", dialog_id(card),
        "Retirer Portal des decks", text: "Retirer des decks"
    end
    assert_select "dialog#trade-picker ##{dialog_id(card)}, form#trade-draft-form ##{dialog_id(card)}", 0
    assert_select "dialog##{dialog_id(card)}[data-controller='dialog']" do
      assert_select ".modal__title", "Retirer Portal de 2 decks ?"
      assert_select "form[action=?][method=post][data-turbo=false]", deck_removals_path(locale: :fr) do
        assert_select "input[type=hidden][name=ref][value=?]", ref_of(card)
        assert_select "button[type=submit]", "Retirer"
      end
    end
    assert_no_match(/data-[a-z-]*id="\d+"/, response.body)
  end

  test "on a trade the friend proposed, the player's board names the decks of their decked card" do
    card = ranked_cards(@player, 1, quantity: 2, titles: [ "Portal" ]).sole
    put_in(deck(@player, "Vieux briscards"), card)
    trade = Game::ProposeTrade.new.call(player: @friend, recipient: @player, offer: {}, request: { card => 1 }).value!
    sign_in(@player)

    get trade_path(locale: :fr, token: trade.token)

    assert_response :success
    assert_select ".trade-pick[data-side='own'][data-key='#{key_of(card)}'][data-max='1']" do
      assert_select ".trade-pick__reserved", "Dans un deck"
      assert_select ".deck-holding__names", "Dans : Vieux briscards"
    end
    assert_select "dialog#trade-picker ##{dialog_id(card)}", 0
    assert_select "dialog##{dialog_id(card)} input[name=ref][value=?]", ref_of(card)
  end

  test "removing frees the copy from every deck and returns to the screen it came from" do
    card = ranked_cards(@player, 1, titles: [ "Portal" ]).sole
    decks = [ deck(@player, "Vieux briscards"), deck(@player, "Nouveaux venus") ]
    decks.each { put_in(it, card) }
    sign_in(@player)
    back = new_trade_path(locale: :fr, friend: @friend.token)

    post deck_removals_path(locale: :fr), params: { ref: ref_of(card) }, headers: { "Referer" => "http://www.example.com#{back}" }

    assert_redirected_to "http://www.example.com#{back}"
    assert_response :see_other
    assert_equal "Portal n'est plus dans aucun deck.", flash[:notice]
    assert_equal 0, reserved_of(@player, card)
    assert_equal 0, Game::DeckCard.where(deck_id: decks.map(&:id)).count
  end

  test "an unknown ref is refused with a toast, and a visitor is sent to sign in" do
    post deck_removals_path(locale: :fr), params: { ref: "portal:1" }
    assert_redirected_to home_path(locale: :fr)

    sign_in(@player)
    post deck_removals_path(locale: :fr), params: { ref: "nothing-here:9" }
    assert_redirected_to new_deck_path(locale: :fr)
    assert_equal Game::RemoveFromDecks.failure_message(:card_not_owned, locale: :fr), flash[:alert]
  end

  test "sixty removals a minute, then a refusal" do
    sign_in(@player)
    with_counting_rate_limit(DeckRemovalsController) do
      60.times { post deck_removals_path(locale: :fr), params: { ref: "nothing-here:9" } }
      post deck_removals_path(locale: :fr), params: { ref: "nothing-here:9" }
    end

    assert_redirected_to new_deck_path(locale: :fr)
    assert_equal I18n.t("decks.removal.throttled", locale: :fr), flash[:alert]
  end

  test "the entrust grid shows a decked edition with no free copy, its decks and its removal" do
    open_market!
    card, free = ranked_cards(@player, 2, titles: [ "Portal", "Hades" ])
    put_in(deck(@player, "Vieux briscards"), card)
    sign_in(@player)

    get new_market_entrustment_path(locale: :fr, filter: { query: "" })

    assert_select ".entrust-cell", 2
    assert_select ".entrust-cell[data-ref='#{ref_of(card)}'][data-free='0']" do
      assert_select ".entrust-cell__reserved", "Dans un deck"
      assert_select ".entrust-cell__toggle[aria-disabled='true'][aria-label*=?]", "dans un deck : Vieux briscards"
      assert_select ".deck-holding__names", "Dans : Vieux briscards"
      assert_select "button[data-dialog-opener-dialog-value=?]", dialog_id(card)
    end
    assert_select ".entrust-cell[data-ref='#{ref_of(free)}'] .deck-holding", 0
    assert_select "form#entrust ##{dialog_id(card)}", 0
    assert_select "dialog##{dialog_id(card)} input[name=ref][value=?]", ref_of(card)
  end

  test "a card page whose only edition a deck blocks opens with nothing ticked" do
    open_market!
    card = ranked_cards(@player, 1, titles: [ "Portal" ]).sole
    put_in(deck(@player, "Vieux briscards"), card)
    sign_in(@player)

    get new_market_card_entrustment_path(locale: :fr, slug: ref_of(card).split(":").first)

    assert_select ".entrust-cell[data-ref='#{ref_of(card)}'][data-ticked='0']"
    assert_select "input[name=selection][value='']"
    assert_select ".entrust-ticks span", 0
  end

  test "the sale grid shows a decked edition as not to be chosen, and lists its removal beside the grid" do
    open_market!
    card = ranked_cards(@player, 1, titles: [ "Portal" ]).sole
    put_in(deck(@player, "Vieux briscards"), card)
    sign_in(@player)

    get new_market_sale_path(locale: :fr)

    assert_select "#listing-form input[name=ref][value='']"
    assert_select ".sale-cell[data-ref='#{ref_of(card)}'][aria-disabled='true'][aria-selected='false'][aria-label*=?]",
      "dans un deck : Vieux briscards" do
      assert_select ".sale-cell__reserved", "Dans un deck"
      assert_select ".sale-cell__decks", "Dans : Vieux briscards"
      assert_select "button", 0
    end
    assert_select "#sale-decked .sale-decked" do
      assert_select ".sale-decked__title", "Portal · S#{ref_of(card).split(":").last}"
      assert_select "button[data-dialog-opener-dialog-value=?]", dialog_id(card)
    end
    assert_select "form#listing-form ##{dialog_id(card)}", 0
    assert_select "dialog##{dialog_id(card)}"
  end

  test "a decked edition on the next page joins the list beside the grid through the page's stream" do
    open_market!
    cards = ranked_cards(@player, 61)
    last = cards.last
    Catalog::CardText.where(card_id: card_of(last)).update_all(title: "Zork")
    put_in(deck(@player, "Vieux briscards"), last)
    sign_in(@player)

    get new_market_sale_path(locale: :fr)
    assert_select "#sale-cells > .sale-cell", 60
    assert_select "#sale-decked .sale-decked", 0

    get new_market_sale_path(locale: :fr, page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_select "turbo-stream[action=append][target=sale-cells] template .sale-cell[data-ref=?]", ref_of(last)
    assert_select "turbo-stream[action=append][target=sale-decked] template .sale-decked .sale-decked__title", /\AZork/
  end

  test "a forged sale or entrustment of a copy a deck blocks is refused and moves nothing" do
    settings = open_market!
    Game::Market::Ledger.post(Game::Market::Mint.credit(player_id: @player.id, amount: 1_000_000, settings_id: settings.id))
    card = ranked_cards(@player, 1, titles: [ "Portal" ]).sole
    put_in(deck(@player, "Vieux briscards"), card)
    sign_in(@player)

    assert_no_difference [ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:reserved) },
                           -> { Game::Holding.sum(:quantity) } ] do
      post market_sales_path(locale: :fr), params: { settings: settings.token, ref: ref_of(card), starting_price: "1000000",
        duration_hours: settings.duration_short_hours.to_s }
      assert_response :unprocessable_content

      post market_entrustments_path(locale: :fr), params: { settings: settings.token, selection: "#{ref_of(card)}=1" }
      assert_response :unprocessable_content
    end
    assert_equal 1, reserved_of(@player, card)
  end
end
