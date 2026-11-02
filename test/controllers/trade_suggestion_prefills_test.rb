require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# A suggestion's two ways in, the opener's prefilled board and ENVOYER, keep
# only the cards still spared when they are followed, not when the list was read.
class TradeSuggestionPrefillsTest < ActionDispatch::IntegrationTest
  include CustomSets
  include GameSets
  include Holdings
  include SteamSignIn

  def sign_in_origin = "/fr"

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @alice.update!(persona_name: "Hugo")
    @bob.update!(persona_name: "Lea")
    [ @bob, @carol ].each { befriend(@alice, it) }
    @portal = catalog_card_seasons(:portal_one).id
    @soldier = catalog_card_seasons(:common_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    @crown = catalog_card_seasons(:legendary_card_one).id
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def goal_on(*card_season_ids)
    card_ids = Catalog::CardSeason.where(id: card_season_ids).pluck(:card_id)
    name = "Objectif #{Game::Goal.where(player_id: @alice.id).count + 1}"
    Game::AddGoal.new.call(player: @alice, custom_set: create_custom_set(@alice, name:, card_ids:).token).value!
  end

  def suggest_from_lea
    hold(@alice, @soldier)
    goal_on(@soldier, @hills, @depths)
    hold(@bob, @depths, 2)
    hold(@bob, @hills, 2)
  end

  def key_of(card_season_id)
    card_season = Catalog::CardSeason.find(card_season_id)
    "#{Catalog::Card.find(card_season.card_id).slug}--s#{Catalog::Season.find(card_season.season_id).number}"
  end

  def opener_href
    get trades_path(locale: :fr)
    css_select(".trade-suggestion__opener").sole["href"]
  end

  def board_lines = css_select("[data-trade-board-target='line']").map { [ it["data-side"], it["data-key"], it["data-quantity"].to_i ] }

  def taken(*ids) = ids.map { [ "friend", key_of(it), 1 ] }

  def send_suggestion(take: { "blue-depths--s1" => 1, "green-hills--s1" => 1 })
    post suggestions_trades_path(locale: :fr), params: { friend: @bob.token, take:, position: 0 }
  end

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  test "the opener's prefilled board marks the cards of the viewer's goal with their bookmark" do
    suggest_from_lea
    sign_in @alice

    get opener_href

    lines = css_select(".trade-card--editing[data-key]")
    assert_equal [ [ "blue-depths--s1", [ 1 ] ], [ "green-hills--s1", [ 1 ] ] ],
      lines.map { |line| [ line["data-key"], line.css(".card > .card__goals > .goal-bookmark").map { it.text.to_i } ] }.sort
    assert_select ".trade-card--editing .visually-hidden", text: /objectif 1/, minimum: 2
  end

  test "six spared games:the opener holds the first four and the board places them in that order" do
    unheld = unheld_cards(1).sole
    goal_on(@soldier, unheld, @depths)
    goal_on(@portal, @crown, @hills)
    [ @soldier, unheld, @depths, @portal, @crown, @hills ].each { hold(@bob, it, 2) }
    sign_in @alice

    href = opener_href
    expected = [ @depths, @soldier, unheld, @crown ]
    assert_equal new_trade_path(locale: :fr, friend: @bob.token, take: expected.map { key_of(it) }), href

    get href
    assert_equal taken(*expected), board_lines
  end

  test "the opener followed after the friend's copy was traded away, reserved or put in an open trade places the rest" do
    suggest_from_lea
    sign_in @alice
    href = opener_href
    hills = Game::Holding.find_by!(player_id: @bob.id, card_season_id: @hills)

    hills.update!(quantity: 0)
    get href
    assert_equal taken(@depths), board_lines

    hills.update!(quantity: 2, reserved: 2)
    get href
    assert_equal taken(@depths), board_lines

    hills.update!(reserved: 0)
    get href
    assert_equal taken(@depths, @hills), board_lines

    propose(@alice, @bob, offer: {}, request: { @hills => 1 })
    get href
    assert_equal taken(@depths), board_lines
  end

  test "the player's give cards no longer spared for the friend are dropped" do
    suggest_from_lea
    hold(@alice, @portal, 3)
    hold(@alice, @crown, 3)
    propose(@alice, @bob, offer: { @portal => 1 }, request: { @depths => 1 })
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @bob.token, take: %w[green-hills--s1], give: [ key_of(@soldier), key_of(@portal), key_of(@crown) ])

    assert_equal taken(@hills) + [ [ "own", key_of(@soldier), 1 ], [ "own", key_of(@crown), 1 ] ], board_lines
  end

  test "a prefilled board carries the friend's plain new-trade address and the send action; a plain board neither" do
    suggest_from_lea
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @bob.token, take: %w[blue-depths--s1])
    root = css_select("#trade-board").sole
    assert_equal new_trade_path(locale: :fr, friend: @bob.token), root["data-trade-board-board-url-value"]
    assert_equal "submit->trade-board#send", css_select("form#trade-draft-form").sole["data-action"]

    get new_trade_path(locale: :fr, friend: @bob.token)
    assert_nil css_select("#trade-board").sole["data-trade-board-board-url-value"]
    assert_nil css_select("form#trade-draft-form").sole["data-action"]
  end

  test "ENVOYER after a card is no longer free requests the rest; with every card gone it is refused and nothing is proposed" do
    suggest_from_lea
    sign_in @alice
    Game::Holding.where(player_id: @bob.id, card_season_id: @hills).update_all("reserved = quantity")

    assert_difference -> { Game::Trade.count }, 1 do
      send_suggestion
    end
    assert_equal [ [ "request", @depths, 1 ] ], Game::Trade.last.items.map { [ it.side, it.card_season_id, it.quantity ] }

    Game::Holding.where(player_id: @bob.id, card_season_id: @depths).update_all("reserved = quantity")

    assert_no_difference -> { Game::Trade.count } do
      send_suggestion
    end
    assert_redirected_to trades_path(locale: :fr)
    assert_equal "Exemplaires insuffisants : une carte demandée n'est plus disponible. Rien n'a bougé.", flash[:alert]
    assert_equal "Exemplaires insuffisants", flash[:toast_title]
    assert_nil flash[:trade_error]
  end

  test "ENVOYER drops the player's give cards no longer spared for the friend and proposes the rest" do
    suggest_from_lea
    hold(@alice, @portal, 3)
    hold(@alice, @crown, 1, reserved: 1)
    sign_in @alice

    assert_difference -> { Game::Trade.count }, 1 do
      post suggestions_trades_path(locale: :fr),
        params: { friend: @bob.token, take: { "blue-depths--s1" => 1 }, give: { key_of(@crown) => 1, key_of(@portal) => 1 }, position: 0 }
    end

    assert_equal [ [ "offer", @portal, 1 ], [ "request", @depths, 1 ] ],
      Game::Trade.last.items.order(:side).map { [ it.side, it.card_season_id, it.quantity ] }
  end

  test "a crafted prefill of a card the friend has no free copy of ignores it" do
    suggest_from_lea
    hold(@bob, @crown, 1, reserved: 1)
    sign_in @alice

    get new_trade_path(locale: :fr, friend: @bob.token, take: [ key_of(@crown), "blue-depths--s1" ])

    assert_equal taken(@depths), board_lines
  end
end
