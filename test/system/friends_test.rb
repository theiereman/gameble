require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/steam_sign_in"

class FriendsTest < ApplicationSystemTestCase
  include CatalogSeeds
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @friend.update_columns(persona_name: "Lea", visibility: "friends_only")
    Game::Friendship.create!(low_player_id: [ @player.id, @friend.id ].min, high_player_id: [ @player.id, @friend.id ].max)
    season = publish_sets_draft
    Catalog::CardSeason.where(season_id: season.id).order(rarity: :desc, id: :asc).limit(4).pluck(:id).each do |id|
      Game::Holding.create!(player_id: @friend.id, card_season_id: id, quantity: 1)
    end
    mock_steam_sign_in(@player.steam_id)
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit friends_path(locale: :en)
  end

  def no_horizontal_scroll?
    page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  def befriend(fixture, name)
    accounts_players(fixture).tap do |friend|
      friend.update_columns(persona_name: name, visibility: "public")
      Game::Friendship.create!(low_player_id: [ @player.id, friend.id ].min, high_player_id: [ @player.id, friend.id ].max)
    end
  end

  def box(selector)
    page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, width: r.width } })()").transform_keys(&:to_sym)
  end

  def profile_actions_box(part)
    box("dialog[open] .friend-profile__actions #{part}")
  end

  def press_escape
    page.driver.browser.action.send_keys(:escape).perform
  end

  def lefts(selector)
    page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].map((e) => Math.round(e.getBoundingClientRect().left))")
  end

  test "a player opens a friend's profile, sees no showcase and reports it from its more-actions menu" do
    sign_in

    within(".friends__friend", text: "Lea") { click_on "Lea" }

    within("dialog#friend-#{@friend.token}[open]") do
      assert_selector ".friend-profile__name", text: "Lea"
      assert_no_selector ".friend-profile__showcase"
      assert_selector "a.button--primary[href='#{new_trade_path(locale: :en, friend: @friend.token)}']", text: /\Atrade\z/i
      assert_no_button "Report"
      find("button.friends__more-button[aria-label='More actions for Lea']").click
      assert_selector ".friends__menu:popover-open", text: /report.*remove/im
      take_screenshot
      click_on "Report"
    end
    within("dialog#report-dialog-#{@friend.token}[open]") { find(".modal__close").click }
    assert_no_selector "dialog#report-dialog-#{@friend.token}[open]"
    assert_selector "dialog#friend-#{@friend.token}[open] button.friends__more-button[aria-label='More actions for Lea']:focus"

    within("dialog#friend-#{@friend.token}[open]") do
      find("button.friends__more-button").click
      click_on "Report"
    end
    within("dialog#report-dialog-#{@friend.token}[open]") do
      choose "Harassment"
      click_on "SEND THE REPORT"
    end

    assert_current_path friends_path(locale: :en)
    assert_selector ".toast", text: /moderation team will review this profile/i
    assert_equal 1, Accounts::Report.where(reporter_id: @player.id, reported_id: @friend.id).count
  end

  test "a player proposes a trade from a friend's row, and reaches the friend's profile and collection from the friend profile" do
    sign_in

    within(".friends__friend", text: "Lea") do
      assert_no_selector "a.friends__profile-link"
      assert_no_button "See the profile"
      click_on "Trade"
    end
    assert_current_path new_trade_path(locale: :en, friend: @friend.token)

    visit friends_path(locale: :en)
    within(".friends__friend", text: "Lea") { click_on "Lea" }
    within("dialog#friend-#{@friend.token}[open]") do
      assert_selector "a.friends__profile-link[aria-label=\"See Lea's profile\"]", text: /see the profile/i
      assert_selector "a.friends__collection-link[aria-label=\"See Lea's collection\"]", text: /see the collection/i
      find("a.friends__collection-link").click
    end
    assert_current_path brother_collection_path(locale: :en, token: @friend.token)
    assert_selector ".collection-grid .collection-slot"
    assert_selector ".collection-slot .card--not-owned"
  end

  test "on a desktop the friend profile sets the trade beside its more-actions button and the two views side by side under it, unfilled" do
    sign_in

    within(".friends__friend", text: "Lea") { click_on "Lea" }
    within("dialog#friend-#{@friend.token}[open]") { assert_selector ".friends__collection-link" }

    trade, more = profile_actions_box(".friend-profile__trade .button"), profile_actions_box(".friends__more-button")
    profile, collection = profile_actions_box(".friends__profile-link"), profile_actions_box(".friends__collection-link")
    assert_operator more[:left], :>, trade[:right], "⋯ beside the trade"
    assert_in_delta profile[:top], collection[:top], 1, "the two views on one line"
    assert_operator profile[:top], :>, trade[:top], "the views under the trade"
    assert_in_delta profile[:width], collection[:width], 1
    assert_in_delta trade[:left], profile[:left], 1
    assert_in_delta trade[:right], collection[:right], 1
    fills = page.evaluate_script("[...document.querySelectorAll('dialog[open] .friend-profile__view')].map((e) => getComputedStyle(e).backgroundColor)")
    assert_equal [ "rgba(0, 0, 0, 0)" ] * 2, fills
    take_screenshot

    press_escape
    assert_no_selector "dialog[open]"
    assert_selector ".friends__friend button[aria-label='See the profile of Lea']:focus"
  end

  test "a player removes a friend from the friend profile's more-actions menu" do
    sign_in

    within(".friends__friend", text: "Lea") { click_on "Lea" }
    within("dialog#friend-#{@friend.token}[open]") do
      find("button.friends__more-button[aria-label='More actions for Lea']").click
      click_on "Remove"
    end
    within("dialog#friend-profile-remove-#{@friend.token}[open]") do
      assert_selector ".modal__title", text: /\Aremove lea\?\z/i
      click_on "Cancel"
    end
    assert_no_selector "dialog#friend-profile-remove-#{@friend.token}[open]"
    assert_selector "dialog#friend-#{@friend.token}[open] button.friends__more-button:focus"

    within("dialog#friend-#{@friend.token}[open]") do
      find("button.friends__more-button").click
      click_on "Remove"
    end
    within("dialog#friend-profile-remove-#{@friend.token}[open]") { click_on "Remove" }

    assert_selector ".toast", text: "Lea is no longer one of your friends."
    assert_no_selector ".friends__friend"
    assert_not Game::FriendshipBetween.call(@player, @friend)
  end

  test "a player opens the trade in progress with a friend from their row" do
    offered, requested = Game::Holding.where(player_id: @friend.id).order(:card_season_id).limit(2).pluck(:card_season_id)
    Game::Holding.create!(player_id: @player.id, card_season_id: requested, quantity: 1)
    trade = Game::ProposeTrade.new.call(player: @friend, recipient: @player, offer: { offered => 1 }, request: { requested => 1 }).value!
    sign_in

    within(".friends__friend", text: "Lea") { click_on "Trade" }

    assert_current_path trade_path(locale: :en, token: trade.token)
    assert_no_selector ".toast", text: /one trade at a time/i
  end

  test "a player opens the trade in progress with a friend from the friend profile" do
    offered, requested = Game::Holding.where(player_id: @friend.id).order(:card_season_id).limit(2).pluck(:card_season_id)
    Game::Holding.create!(player_id: @player.id, card_season_id: requested, quantity: 1)
    trade = Game::ProposeTrade.new.call(player: @friend, recipient: @player, offer: { offered => 1 }, request: { requested => 1 }).value!
    sign_in

    within(".friends__friend", text: "Lea") { click_on "Lea" }
    within("dialog#friend-#{@friend.token}[open]") { click_on "Trade" }

    assert_current_path trade_path(locale: :en, token: trade.token)
    assert_no_selector ".toast", text: /one trade at a time/i
  end

  test "on a phone the profile is a bottom sheet that closes back on the friend's name" do
    resize_to(390, 844)
    sign_in

    side, main = box(".friends__side"), box(".friends__main")
    assert_operator main[:top], :>, side[:top], "one column, the invite panel and invitations first"
    assert_in_delta side[:left], main[:left], 1
    scroll_to(find(".friends__friend", text: "Lea"))
    take_screenshot

    within(".friends__friend", text: "Lea") { click_on "Lea" }
    within("dialog#friend-#{@friend.token}[open]") do
      assert_selector ".friend-profile__name", text: "Lea"
      assert_selector ".friends__collection-link"
    end
    trade, more = profile_actions_box(".friend-profile__trade .button"), profile_actions_box(".friends__more-button")
    profile, collection = profile_actions_box(".friends__profile-link"), profile_actions_box(".friends__collection-link")
    assert_operator more[:left], :>, trade[:right], "⋯ beside the trade"
    assert_operator collection[:top], :>, profile[:top], "the two views stacked"
    [ profile, collection ].each do |view|
      assert_in_delta trade[:left], view[:left], 1
      assert_in_delta trade[:width], view[:width], 1
    end
    within("dialog#friend-#{@friend.token}[open]") do
      take_screenshot
      find(".modal__close").click
    end

    assert_no_selector "dialog[open]"
    assert_selector ".friends__friend button[aria-label='See the profile of Lea']:focus"
    assert no_horizontal_scroll?
  end

  test "on a desktop the friend list is the wider area, on the right, with each part of every row in the same place" do
    befriend(:administrator, "Maximilien-Alexandre the Patient")
    sign_in

    side, main = box(".friends__side"), box(".friends__main")
    assert_operator main[:left], :>, side[:right], "the friend list stands right of the invite panel and invitations"
    assert_operator main[:width], :>, side[:width] * 1.5
    assert_selector ".friends__friend", count: 2
    [ ".friends__presence", ".friends__trade", ".friends__more-button" ].each do |part|
      assert_equal 1, lefts(".friends__friend #{part}").uniq.size, "#{part} starts at the same place in every row"
    end
    within(".friends__friend", text: "Maximilien") { assert_selector ".button", count: 2 }
    assert no_horizontal_scroll?
    take_screenshot
  end

  test "on a desktop the empty friend list still leads, with the no-friend and no-invitation lines" do
    Game::Friendship.delete_all
    sign_in

    side, main = box(".friends__side"), box(".friends__main")
    assert_operator main[:width], :>, side[:width]
    within(".friends__main") { assert_selector ".friends__empty", text: "No friends yet. Invite one with your link or your code." }
    within(".friends__side") { assert_selector ".friends__empty", text: "No invitation pending." }
    take_screenshot
  end

  test "a player removes a friend from the more-actions menu, after a confirmation that can be cancelled" do
    sign_in

    within(".friends__friend", text: "Lea") do
      assert_no_button "Remove"
      find("button.friends__more-button[aria-label='More actions for Lea']").click
      assert_selector ".friends__menu:popover-open"
      take_screenshot
      click_on "Remove"
    end
    within("dialog#remove-friend-#{@friend.token}[open]") do
      assert_selector ".modal__title", text: /\Aremove lea\?\z/i
      click_on "Cancel"
    end
    assert_no_selector "dialog[open]"
    assert_no_selector ".friends__menu:popover-open"
    assert_selector ".friends__friend button.friends__more-button[aria-label='More actions for Lea']:focus"

    within(".friends__friend", text: "Lea") do
      find("button.friends__more-button").click
      click_on "Remove"
    end
    within("dialog#remove-friend-#{@friend.token}[open]") { click_on "Remove" }

    assert_selector ".toast", text: "Lea is no longer one of your friends."
    assert_no_selector ".friends__friend"
    assert_not Game::FriendshipBetween.call(@player, @friend)
  end
end
