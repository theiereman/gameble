require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/active_titles"
require_relative "../support/steam_sign_in"

# The activity feed's frame: as wide as the hub on a desktop, signed in, the
# All and Friends tabs then one chip naming the type in force, on one line;
# that chip opens a bottom sheet of the five type filters. On a phone no chip
# is cut and the column never scrolls sideways. Friends shows only a
# player's friends' entries, combines with the type, invites a player without
# friends to add some, and is disabled for a visitor.
class FeedTest < ApplicationSystemTestCase
  include GamePacks
  include ActiveTitles
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
    open_epic(@player)
  end

  test "scrolling to the end of a long feed appends the older entries, then stops asking" do
    (Game::FeedEntries::LIMIT / 5).times { open_epic(@player) }
    visit feed_path(locale: :en)
    assert_selector "#feed-entries > li.feed__entry", count: Game::FeedEntries::LIMIT

    page.execute_script("document.querySelector('.feed__pages').scrollIntoView()")

    assert_selector "#feed-entries > li.feed__entry", count: Game::FeedEntry.where(notable: true).count
    assert_no_selector ".feed__pages"
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

  test "in French, the tabs and the type sheet each show their own word for all, once" do
    visit feed_path(locale: :fr)

    assert_pull_entries 5, "a tiré"
    within(".feed__tabs") do
      assert_selector ".feed__tab", text: /\ATous\z/i, count: 1
      assert_selector ".feed__tab", text: /\AAmis\z/i, count: 1
      assert_no_text(/\bTout\b/i)
    end
    within(".feed") { assert_text(/\bTout\b/i, count: 1) }
    assert_selector ".feed__type-opener", text: /\AType\u202f: Tout\z/i

    open_type_sheet
    within("dialog#feed-types[open] .feed__filters") do
      assert_selector ".feed__filter", text: /\ATout\z/i, count: 1
      assert_no_text(/\bTous\b/i)
    end
  end

  test "on a phone, the feed keeps its column with no sideways scroll" do
    resize_to(*PHONE)
    visit feed_path(locale: :en)

    assert_pull_entries 5
    assert_one_everything
    assert_no_sideways_scroll
  end

  test "on a desktop, the tabs then the type chip sit on one line, past a divider, aligned on the list" do
    visit feed_path(locale: :fr)

    assert_pull_entries 5, "a tiré"
    assert_selector ".feed__controls .filter-chip", count: 3
    eventually("the tabs and the type chip should share one line, the tabs first, the zone on the list's left edge") do
      layout = controls_layout
      layout["tops"].uniq.size == 1 && layout["tabsRight"] < layout["openerLeft"] &&
        (layout["firstChipLeft"] - layout["listLeft"]).abs <= 1 && !layout["scrolls"]
    end
    assert_not_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('.feed__type-opener')).boxShadow"),
      "a divider should set the type chip apart from the tabs"
    assert_match(/\ATous\z/i, find(".feed__tab[aria-current]").native.accessible_name)
    assert_match(/\AAmis\z/i, find(".feed__tab[disabled]").native.accessible_name)
  end

  test "on a phone, the type chip opens the sheet, a choice there names the new type, and no chip is cut" do
    resize_to(*PHONE)
    visit feed_path(locale: :en)

    assert_pull_entries 5
    assert chips_inside_the_page?, "no chip should be cut at the right edge"
    assert_no_sideways_scroll

    choose_type "Reposts"

    assert_selector ".feed__type-opener", text: /\AType: Reposts\z/i
    assert_no_selector "dialog#feed-types[open]"
    assert_selector ".feed__filter[aria-current]", text: /\AReposts\z/i, visible: :all
    assert chips_inside_the_page?, "no chip should be cut at the right edge"
    assert_no_sideways_scroll
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

    choose_type "Pulls"
    assert_selector ".feed__type-opener", text: /\AType: Pulls\z/i
    assert_selector ".feed__tab[aria-current]", text: /\AFriends\z/i
    assert_pull_entries 5
    assert_no_selector ".feed__sentence", text: "Léa"

    find(".feed__tab", text: /\AAll\z/i).click
    assert_selector ".feed__tab[aria-current]", text: /\AAll\z/i
    assert_selector ".feed__type-opener", text: /\AType: Pulls\z/i
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

  test "a feed line shows the title its player wears" do
    earn_title(@player)
    visit feed_path(locale: :en)

    assert_selector ".feed__sentence .profile-title", text: /\A#{ACTIVE_TITLE_TEXT}\z/i, minimum: 1
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
      assert_selector ".feed__type-opener", text: /\AType: Everything\z/i, count: 1
      assert_selector ".feed__filter", text: /\AEverything\z/i, count: 1, visible: :all
      assert_selector ".feed__filter[aria-current]", text: /\AEverything\z/i, visible: :all
    end

    def open_type_sheet
      find(".feed__type-opener").click
      assert_selector "dialog#feed-types[open]"
    end

    def choose_type(name)
      open_type_sheet
      within("dialog#feed-types[open]") { find(".feed__filter", text: /\A#{name}\z/i).click }
    end

    def assert_no_sideways_scroll
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the feed should not scroll sideways"
    end

    def chips_inside_the_page?
      page.evaluate_script(<<~JS)
        (() => {
          const right = document.documentElement.clientWidth;
          return [...document.querySelectorAll(".feed__controls .filter-chip")].every((chip) => chip.getBoundingClientRect().right <= right);
        })()
      JS
    end

    def controls_layout
      page.evaluate_script(<<~JS)
        (() => {
          const zone = document.querySelector(".feed__controls");
          const chips = [...zone.querySelectorAll(".filter-chip")];
          return {
            tops: chips.map((chip) => Math.round(chip.getBoundingClientRect().top)),
            tabsRight: zone.querySelector(".feed__tabs").getBoundingClientRect().right,
            openerLeft: zone.querySelector(".feed__type-opener").getBoundingClientRect().left,
            firstChipLeft: chips[0].getBoundingClientRect().left,
            listLeft: document.querySelector(".feed__list").getBoundingClientRect().left,
            scrolls: zone.scrollWidth > zone.clientWidth
          };
        })()
      JS
    end

    def width_of(selector)
      page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
    end
end
