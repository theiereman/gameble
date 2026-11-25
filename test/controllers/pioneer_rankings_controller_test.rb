require "test_helper"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"
require_relative "../support/supporters"

class PioneerRankingsControllerTest < ActionDispatch::IntegrationTest
  include GameSets
  include SteamSignIn
  include Supporters

  STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
    accounts_players(:banned).update!(persona_name: "Exiled")
  end

  def pioneer(number, name, **attributes)
    Accounts::Player.create!(steam_id: (76561197960600000 + number).to_s, persona_name: name, **attributes)
  end

  def discover(player, card_season_ids, at: Time.current)
    Game::FirstDiscovery.insert_all!(Array(card_season_ids).map do |card_season_id|
      { card_season_id:, player_id: player.id, discovered_at: at, created_at: at, updated_at: at }
    end)
  end

  test "a visitor reads every active pioneer by name, a private one unlinked, with no place and one sign-in line" do
    _season, cards = published_cards(4)
    discover(pioneer(1, "Lea"), cards[0, 2])
    discover(pioneer(2, "Hidden", visibility: "private"), cards[2])
    discover(accounts_players(:banned), cards[3])

    get pioneer_ranking_path(locale: :en)

    assert_response :success
    assert_select "h1", "Pioneer ranking"
    assert_select "#pioneer-ranking-rows li.pioneer-row", 2
    assert_select "#pioneer-ranking-rows li.pioneer-row:nth-child(1)" do
      assert_select ".pioneer-row__rank", "#1"
      assert_select "a.player-name--linked", "Lea"
      assert_select ".pioneer-row__count .visually-hidden", "2 discoveries"
    end
    assert_select "#pioneer-ranking-rows li.pioneer-row:nth-child(2) span.player-name", "Hidden"
    assert_select ".pioneer-row", text: /Exiled/, count: 0
    assert_select ".pioneer-place", false
    assert_select "#pioneer-ranking-me", false
    assert_select ".pioneer-ranking__visitor", 1
    assert_select ".pioneer-ranking__visitor", /Join the Brotherhood to discover the missing cards\./
    assert_select ".pioneer-ranking__visitor a.button--primary"
  end

  test "a signed-in viewer sees the pressed chips, their own row and the link to their place" do
    _season, cards = published_cards(3)
    discover(pioneer(1, "Lea"), cards[0, 2])
    discover(@player, cards[2])
    sign_in(@player)

    get pioneer_ranking_path(locale: :en)

    assert_response :success
    assert_select "button.segmented__option[name=seasons][value=all][aria-pressed=true]", "All seasons"
    assert_select "button.segmented__option[name=period][value=week][aria-pressed=true]", "Week"
    assert_select "button.segmented__option[name=period][value=season][aria-pressed=false]", "Total"
    assert_select "li#pioneer-ranking-me.pioneer-row[tabindex='-1']" do
      assert_select ".pioneer-row__rank", "#2"
      assert_select ".pioneer-row__you", "You"
    end
    assert_select "a.pioneer-place__link[href=?]", "/en/inventory/pioneers?page=1#pioneer-ranking-me",
      text: "Your place: #2, 1 discovery, go to my row"
    assert_select ".pioneer-ranking__visitor", false
  end

  test "the current season's Season period counts only the published season's discoveries" do
    _old, old_cards = published_cards(2)
    _current, current_cards = published_cards(1)
    lea = pioneer(1, "Lea")
    discover(lea, old_cards)
    discover(lea, current_cards, at: 2.weeks.ago)

    get pioneer_ranking_path(locale: :en, seasons: "current", period: "season")

    assert_response :success
    assert_select "button.segmented__option[name=seasons][value=current][aria-pressed=true]", "Current season"
    assert_select "button.segmented__option[name=period][value=season][aria-pressed=true]", "Season"
    assert_select "input[type=hidden][name=seasons][value=current]"
    assert_select "input[type=hidden][name=period][value=season]"
    assert_select "#pioneer-ranking-rows li.pioneer-row", 1
    assert_select "#pioneer-ranking-rows .pioneer-row__count .visually-hidden", "1 discovery"
  end

  test "an empty period reads its empty line" do
    get pioneer_ranking_path(locale: :fr)

    assert_response :success
    assert_select "h1", "Classement des pionniers"
    assert_select ".pioneer-ranking__empty", "Aucune découverte cette semaine pour l'instant."
    assert_select "#pioneer-ranking-rows", false
  end

  test "the next page answers as a Turbo Stream: its rows appended, the status line, the pages and the address" do
    _season, cards = published_cards(51)
    51.times { |index| discover(pioneer(index + 1, "Pioneer #{index}"), cards[index], at: Time.current - index.seconds) }

    get pioneer_ranking_path(locale: :en, page: 2), headers: STREAM

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=append][target=pioneer-ranking-rows] template li.pioneer-row", 1
    assert_equal "Page 2 loaded", css_select("turbo-stream[action=update][target=pioneer-ranking-status] template").sole.text
    assert_select "turbo-stream[action=replace][target=collection-pages] template nav#collection-pages [aria-current=page]", /2/
    assert_select "turbo-stream[action=replace][target=pioneer-ranking-address] template span#pioneer-ranking-address[data-url=?]",
      "/en/inventory/pioneers?page=2"
  end

  test "a supporter's row carries the VIP badge after their name, in the ranking and on the Grand Inventaire's boards" do
    _season, cards = published_cards(2)
    lea = pioneer(1, "Lea")
    discover(lea, cards[0])
    discover(pioneer(2, "Max"), cards[1])
    grant_supporter(lea)

    assert_queries_match(/supporter_at/, count: 1) { get pioneer_ranking_path(locale: :en) }

    assert_select "#pioneer-ranking-rows .pioneer-row__who .supporter-badge--compact", 1
    assert_select "#pioneer-ranking-rows .pioneer-row__who a.player-name + .supporter-badge", 1
    assert_select ".pioneer-row__who", text: /Lea\s+VIP/, count: 1
    assert_select ".pioneer-row__who", text: /Max/ do |who|
      assert_select who, ".supporter-badge", 0
    end

    get grand_inventory_path(locale: :en, view: "pioneers")

    assert_select ".pioneer-boards .pioneer-row__who .supporter-badge--compact", 2
  end
end
