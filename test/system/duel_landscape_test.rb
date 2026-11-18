require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# A phone turned sideways plays the duel without the page ever scrolling: the header is one line, the two decks are
# lists that scroll inside their own column and the table sits between them.
class DuelLandscapeTest < ApplicationSystemTestCase
  include SteamSignIn
  include LiveDuels

  LANDSCAPE = [ 844, 390 ].freeze

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: @duel.id).update_all(first_caller: "challenger")
  end

  teardown { resize_to(*SCREEN_SIZE) }

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  # The window size includes the browser's own frame: ask again for the difference.
  def resize_viewport_to(width, height)
    resize_to(width, height)
    inner = page.evaluate_script("[window.innerWidth, window.innerHeight]")
    resize_to(width + (width - inner[0]), height + (height - inner[1]))
  end

  def metrics(selector)
    page.evaluate_script("(() => { const e = document.querySelector('#{selector}'); const r = e.getBoundingClientRect(); " \
      "return { top: r.top, bottom: r.bottom, left: r.left, right: r.right, scrollHeight: e.scrollHeight, clientHeight: e.clientHeight } })()").symbolize_keys
  end

  test "both decks scroll inside their column and the page itself does not" do
    resize_viewport_to(*LANDSCAPE)
    sign_in(@lea)
    visit duel_path(locale: :en, token: @duel.token)
    assert_selector "#duel-board[data-move-number='1']"

    page.save_screenshot(ENV["DUEL_LANDSCAPE_SHOT"]) if ENV["DUEL_LANDSCAPE_SHOT"]
    height = page.evaluate_script("window.innerHeight")
    assert_operator page.evaluate_script("document.documentElement.scrollHeight"), :<=, height
    %w[#duel-my-deck #duel-their-deck].each do |deck|
      assert_operator metrics("#{deck} .duel-deck__cards")[:scrollHeight], :>, metrics("#{deck} .duel-deck__cards")[:clientHeight], deck
      assert_operator metrics(deck)[:bottom], :<=, height, deck
    end
    mine, table, theirs = %w[#duel-my-deck #duel-table #duel-their-deck].map { metrics(it) }
    assert_operator mine[:right], :<=, table[:left]
    assert_operator table[:right], :<=, theirs[:left]
    assert_no_selector ".alpha-banner__warning"
    assert_no_selector ".duel-past"
  end

  test "the card picked for the call shows a gauge and its figure per stat, and no longer the strip of gauges above" do
    resize_viewport_to(*LANDSCAPE)
    sign_in(@lea)
    visit duel_path(locale: :en, token: @duel.token)
    assert_selector "#duel-board[data-move-number='1']"

    first("#duel-my-deck .duel-deck__card--in-hand .duel-deck__body").click

    assert_selector ".duel-call__card:not([hidden]) .duel-call__stat .stat-bars__bar", count: 5
    assert_no_selector ".duel-call__card:not([hidden]) .duel-call__value"
    assert_selector ".duel-call__card:not([hidden]) .duel-call__level", count: 5, text: /\A\d+\z/
    assert_no_selector "#duel-my-deck .duel-deck__card:has(.duel-call__card:not([hidden])) .stat-bars"
    page.save_screenshot(ENV["DUEL_LANDSCAPE_SHOT"]) if ENV["DUEL_LANDSCAPE_SHOT"]
  end

  test "the forfeit button and the alpha tag are centred on the header's height" do
    resize_viewport_to(*LANDSCAPE)
    sign_in(@lea)
    visit duel_path(locale: :en, token: @duel.token)
    assert_selector "#duel-board[data-move-number='1']"

    header = metrics(".duel-header")
    middle = (header[:top] + header[:bottom]) / 2
    [ ".duel-forfeit .button", ".alpha-banner" ].each do |selector|
      box = metrics(selector)
      assert_in_delta middle, (box[:top] + box[:bottom]) / 2, 1, "#{selector} against the header #{header.inspect}, itself #{box.inspect}"
    end
  end
end
