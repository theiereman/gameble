require "test_helper"
require_relative "../support/game_sets"

class PioneerBoardsTest < ActionView::TestCase
  include GameSets
  include PioneerRankingsHelper

  setup { controller.request.path_parameters[:locale] = "en" }

  def pioneer(number, name) = Accounts::Player.create!(steam_id: (76561197960700000 + number).to_s, persona_name: name)

  def discover(player, card_season_ids, at: Time.current)
    Game::FirstDiscovery.insert_all!(Array(card_season_ids).map do |card_season_id|
      { card_season_id:, player_id: player.id, discovered_at: at, created_at: at, updated_at: at }
    end)
  end

  def boards(viewer, inventory_scope: :all)
    render partial: "grand_inventories/pioneer_boards", locals: { inventory_scope:, viewer: }
  end

  def week_board = "section.pioneer-board[aria-labelledby=pioneer-board-week]"

  def rank_fifth(viewer)
    _season, cards = published_cards(15)
    [ 5, 4, 3, 2 ].each_with_index { |count, index| discover(pioneer(index + 1, "Pioneer #{index + 1}"), cards.shift(count)) }
    discover(viewer, cards.shift)
  end

  test "a viewer in the top three is marked beside their name and gets no place line" do
    _season, cards = published_cards(3)
    viewer = pioneer(1, "Hugo")
    discover(pioneer(2, "Lea"), cards[0, 2])
    discover(viewer, cards[2])

    boards(viewer)

    assert_select "#{week_board} h2", "Pioneers · Week"
    assert_select "#{week_board} ol.pioneer-rows li.pioneer-row", 2
    assert_select "#{week_board} li.pioneer-row:nth-child(2) .pioneer-row__you", "You"
    assert_select "#{week_board} .pioneer-board__place", false
    assert_select "#pioneer-ranking-me", false
    assert_select "section.pioneer-board[aria-labelledby=pioneer-board-total] h2", "Pioneers · Total"
  end

  test "a viewer below the top three reads their place outside the list" do
    viewer = pioneer(9, "Hugo")
    rank_fifth(viewer)

    boards(viewer)

    assert_select "#{week_board} ol li.pioneer-row", 3
    assert_select "#{week_board} ol + p.pioneer-board__place" do
      assert_select "span[aria-hidden=true]", "#5 · You · 1"
      assert_select ".visually-hidden", "Your place: #5, 1 discovery"
    end
    assert_select "#{week_board} a.button--link[aria-label=?][href=?]", "See the week's full ranking", "/en/inventory/pioneers",
      text: "See the full ranking"
  end

  test "a viewer without a discovery reads the no-discovery line; under the current season the second board is the Season's" do
    _season, cards = published_cards(1)
    discover(pioneer(1, "Lea"), cards[0])

    boards(pioneer(2, "Hugo"), inventory_scope: :current)

    assert_select "#{week_board} .pioneer-board__place--none", "No discovery this week."
    assert_select "section.pioneer-board[aria-labelledby=pioneer-board-season] h2", "Pioneers · Season"
    assert_select "section.pioneer-board[aria-labelledby=pioneer-board-season] a.button--link[href=?]",
      "/en/inventory/pioneers?period=season&seasons=current"
  end

  test "an empty board reads its empty line only" do
    boards(pioneer(1, "Hugo"))

    assert_select "#{week_board} .pioneer-board__empty", "No discovery this week yet."
    assert_select "#{week_board} ol", false
    assert_select "#{week_board} .pioneer-board__place", false
  end

  test "a visitor gets no place and one sign-in line after both boards" do
    _season, cards = published_cards(1)
    discover(pioneer(1, "Lea"), cards[0])

    boards(nil)

    assert_select ".pioneer-board__place", false
    assert_select ".pioneer-row__you", false
    assert_select ".pioneer-boards > section.pioneer-board", 2
    assert_select ".pioneer-boards > section.pioneer-board ~ p.pioneer-boards__visitor", 1
    assert_select ".pioneer-boards__visitor a.button--primary"
  end
end
