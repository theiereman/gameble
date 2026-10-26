require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The activity feed's frame: as wide as the hub on a desktop, signed in, the
# All and Friends tabs then one "all" filter on one line of chips; on a
# phone, that line scrolls inside its zone and the column never sideways.
# Friends shows only a player's friends' entries, combines with the
# filters, invites a player without friends to add some, and is disabled
# for a visitor.
class FeedTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    open_epic(@player)
  end

  test "signed out, the feed's list shows under one choice of everything, and Friends is disabled" do
    visit feed_path(locale: :en)

    assert_pull_entries 5
    assert_one_everything
    assert_selector ".feed__tab[disabled]", text: /\AFriends\z/i
  end

  test "signed in, the feed's list spans the hub's width under one choice of everything" do
    sign_in

    assert_feed_as_wide_as_the_hub
    assert_one_everything
  end

  test "an entry's player and game link to the profile and the card page" do
    @player.update!(persona_name: "Hugo")
    visit feed_path(locale: :en)

    assert_pull_entries 5
    name = find("a.feed__name", match: :first)
    game = find("a.feed__game", match: :first)
    find(".feed__thumb .card", match: :first).hover
    eventually("the card should be about half of card-s, tilted or not") do
      box = page.evaluate_script("(() => { const r = document.querySelector('.feed__thumb .card').getBoundingClientRect(); return [r.width, r.height] })()")
      box.map(&:round) == [ 56, 84 ]
    end
    assert_match %r{/en/brothers/}, name[:href]
    assert_match %r{/en/cards/}, game[:href]
    game.click
    assert_current_path %r{/en/cards/}
  end

  test "in French, the tabs and the filters each show their own word for all, once" do
    visit feed_path(locale: :fr)

    assert_pull_entries 5, "a tiré"
    within(".feed__tabs") do
      assert_selector ".feed__tab", text: /\ATous\z/i, count: 1
      assert_selector ".feed__tab", text: /\AAmis\z/i, count: 1
      assert_no_text(/\bTout\b/i)
    end
    within(".feed") { assert_text(/\bTout\b/i, count: 1) }
    within(".feed__filters") { assert_no_text(/\bTous\b/i) }
  end

  test "on a phone, the feed keeps its column with no sideways scroll" do
    resize_to(*PHONE)
    visit feed_path(locale: :en)

    assert_pull_entries 5
    assert_one_everything
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the feed should not scroll sideways"
  end

  test "on a desktop, the tabs then the filters sit on one line of chips, past a divider, aligned on the list" do
    visit feed_path(locale: :fr)

    assert_pull_entries 5, "a tiré"
    assert_selector ".feed__controls .filter-chip", count: 7
    eventually("the seven chips should share one line, the tabs before the filters, the zone on the list's left edge") do
      layout = controls_layout
      layout["tops"].uniq.size == 1 && layout["tabsRight"] < layout["filtersLeft"] &&
        (layout["firstChipLeft"] - layout["listLeft"]).abs <= 1 && !layout["scrolls"]
    end
    assert_not_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('.feed__filters')).boxShadow"),
      "a divider should set the filters apart from the tabs"
    assert_match(/\ATous\z/i, find(".feed__tab[aria-current]").native.accessible_name)
    assert_match(/\AAmis\z/i, find(".feed__tab[disabled]").native.accessible_name)
  end

  test "on a phone, the chips keep one line that scrolls inside its zone, and the last one is reachable" do
    resize_to(*PHONE)
    visit feed_path(locale: :en)

    assert_pull_entries 5
    eventually("the chips should keep one line and scroll inside their zone") do
      layout = controls_layout
      layout["tops"].uniq.size == 1 && layout["scrolls"]
    end
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the page should not scroll sideways"

    find(".feed__filter", text: /\AReposts\z/i).click
    assert_selector ".feed__filter[aria-current]", text: /\AReposts\z/i
    eventually("the current Reposts chip should be scrolled into the zone's view") { current_filter_in_view? }
  end

  test "signed in, Friends shows a friend's pull and not a stranger's, and Friends · Pulls keeps both choices" do
    friend = accounts_players(:moderator).tap { it.update!(persona_name: "Sam") }
    stranger = accounts_players(:administrator).tap { it.update!(persona_name: "Léa") }
    Game::Friendship.create!(low_player_id: [ @player.id, friend.id ].min, high_player_id: [ @player.id, friend.id ].max)
    open_epic(friend)
    open_epic(stranger)
    sign_in

    visit feed_path(locale: :en)
    assert_pull_entries 15
    find(".feed__tab", text: /\AFriends\z/i).click

    assert_selector ".feed__tab[aria-current]", text: /\AFriends\z/i
    assert_pull_entries 5
    assert_selector ".feed__sentence", text: "Sam pulled", count: 5
    assert_no_selector ".feed__sentence", text: "Léa"

    find(".feed__filter", text: /\APulls\z/i).click
    assert_selector ".feed__filter[aria-current]", text: /\APulls\z/i
    assert_selector ".feed__tab[aria-current]", text: /\AFriends\z/i
    assert_pull_entries 5
    assert_no_selector ".feed__sentence", text: "Léa"

    find(".feed__tab", text: /\AAll\z/i).click
    assert_selector ".feed__tab[aria-current]", text: /\AAll\z/i
    assert_selector ".feed__filter[aria-current]", text: /\APulls\z/i
    assert_pull_entries 15
  end

  test "signed in without friends, Friends invites to add some and its button leads to the Friends screen" do
    sign_in

    visit feed_path(locale: :fr)
    find(".feed__tab", text: /\AAmis\z/i).click

    assert_selector ".feed__no-friends", text: "Ajoutez des amis pour suivre leurs tirages."
    assert_no_selector ".feed__entry"
    find(".feed__no-friends a.button", text: /\AAjouter des amis\z/i).click

    assert_current_path friends_path(locale: :fr)
    assert_selector "main h1", text: /\AAmis\z/i
  end

  private
    def open_epic(player)
      create_pack(player, cards: [ fixture_tier_ids[3] ] * 5)
      Game::OpenPack.new.call(player:).value!
    end

    def sign_in
      visit home_path(locale: :en)
      click_steam_sign_in
      assert_signed_in
    end

    def assert_feed_as_wide_as_the_hub
      visit home_path(locale: :en)
      assert_selector ".hub"
      hub = width_of(".hub")

      visit feed_path(locale: :en)
      assert_pull_entries 5
      assert_in_delta hub, width_of(".feed__list"), 1, "the feed's list should span the hub's content width"
    end

    def assert_pull_entries(count, verb = "pulled")
      assert_selector ".feed__entry", text: verb, count:
    end

    def assert_one_everything
      assert_selector ".feed__tabs .feed__tab", count: 2
      assert_selector ".feed__tab", text: /\AAll\z/i, count: 1
      assert_selector ".feed__tab", text: /\AFriends\z/i, count: 1
      assert_selector ".feed__tab[aria-current]", text: /\AAll\z/i
      assert_selector ".feed__filter", text: /\AEverything\z/i, count: 1
      assert_selector ".feed__filter[aria-current]", text: /\AEverything\z/i
    end

    def controls_layout
      page.evaluate_script(<<~JS)
        (() => {
          const zone = document.querySelector(".feed__controls");
          const chips = [...zone.querySelectorAll(".filter-chip")];
          return {
            tops: chips.map((chip) => Math.round(chip.getBoundingClientRect().top)),
            tabsRight: zone.querySelector(".feed__tabs").getBoundingClientRect().right,
            filtersLeft: zone.querySelector(".feed__filters .filter-chip").getBoundingClientRect().left,
            firstChipLeft: chips[0].getBoundingClientRect().left,
            listLeft: document.querySelector(".feed__list").getBoundingClientRect().left,
            scrolls: zone.scrollWidth > zone.clientWidth
          };
        })()
      JS
    end

    def current_filter_in_view?
      page.evaluate_script(<<~JS)
        (() => {
          const zone = document.querySelector(".feed__controls").getBoundingClientRect();
          const chip = document.querySelector(".feed__filter[aria-current]").getBoundingClientRect();
          return chip.left >= zone.left && chip.right <= zone.right;
        })()
      JS
    end

    def width_of(selector)
      page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
    end
end
