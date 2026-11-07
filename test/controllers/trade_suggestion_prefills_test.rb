require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# A suggestion's opener's prefilled board keeps
# only the cards still spared when it is followed, not when the list was read.
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

  test "the opener followed after the friend is left with a single free copy places the rest" do
    suggest_from_lea
    sign_in @alice
    href = opener_href

    Game::Holding.where(player_id: @bob.id, card_season_id: @hills).update_all(quantity: 2, reserved: 1)
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
end
