require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The header's bell: its count of lines not yet seen, raised live by a new
# trade or friend request, and lowered for good once a line's target page is
# opened, through the line or any other way; the same bell in the phone's
# top-level header; the empty panel once everything is seen.
class BellTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include GamePacks
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    Game::Invitation.create!(sender_id: @max.id, recipient_id: @hugo.id, status: "pending")
  end

  def sign_in
    mock_steam_sign_in(@hugo.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    forget_seen_lines
    visit home_path(locale: :en)
  end

  def forget_seen_lines
    assert_selector "#bell-items .bell__line", visible: :all, minimum: 1
    page.execute_script("window.localStorage.removeItem('gameble:bell-seen:#{@hugo.token}')")
  end

  def assert_count(count)
    assert_selector ".bell__count", exact_text: count.to_s
    assert_selector ".bell__button .visually-hidden", exact_text: "What is new, #{count} unseen", visible: :all
  end

  def open_bell
    find(".bell__button").click
    assert_selector "#bell-panel:popover-open"
  end

  def signal(topic)
    PlayerStreamJob.perform_now([ { player_id: @hugo.id, topic: } ])
  end

  def propose_trade
    low, high = [ @hugo.id, @lea.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    portal = catalog_card_seasons(:portal_one).id
    depths = catalog_card_seasons(:rare_card_one).id
    Game::Holding.create!(player_id: @hugo.id, card_season_id: portal, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: @lea.id, card_season_id: depths, quantity: 1, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: @lea, recipient: @hugo, offer: { depths => 1 }, request: { portal => 1 }).value!
    perform_enqueued_jobs(only: PlayerStreamJob)
    trade
  end

  test "new lines raise the count live; a line clears once its target is opened, by the line or not, and stays cleared through a reload" do
    sign_in
    assert_count 3
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    trade = propose_trade
    assert_count 4
    ines = Accounts::Player.create!(steam_id: "76561198000009999", persona_name: "Ines")
    Game::Invitation.create!(sender_id: ines.id, recipient_id: @hugo.id, status: "pending")
    signal("friends")
    assert_count 5

    open_bell
    within("#bell-panel") do
      assert_selector ".bell__line", count: 5
      assert_link href: "/en/booster", text: /Your daily capsule is ready/
      assert_link href: "/en/social#community-goal", text: /This week's mission/
      click_link href: "/en/trades/#{trade.token}", text: /Lea awaits your answer to a trade/
    end
    assert_current_path "/en/trades/#{trade.token}"
    assert_count 4

    visit friends_path(locale: :en)
    assert_count 2
    visit library_path(locale: :en)
    assert_count 2
    open_bell
    within("#bell-panel") do
      assert_selector ".bell__line", count: 2
      assert_no_link href: "/en/friends"
      assert_no_link href: "/en/trades/#{trade.token}"
    end

    @max.update!(persona_name: "Maxime")
    signal("friends")
    assert_selector "#bell-items .bell__line", text: /Maxime invites you/, visible: :all
    within("#bell-panel") { assert_selector ".bell__line", count: 2 }
    assert_count 2
  end

  test "marking all as read clears every line that can be seen away and leaves the lasting ones" do
    sign_in
    assert_count 3

    open_bell
    within("#bell-panel") { click_on "Mark all as read" }

    assert_count 2
    within("#bell-panel") do
      assert_selector ".bell__line", count: 2
      assert_no_link href: "/en/friends"
      assert_no_button "Mark all as read"
    end
  end

  test "the daily line stays on the capsule screen until the capsule is collected, then leaves the count" do
    sign_in
    visit booster_path(locale: :en)
    assert_count 3
    assert_selector "#bell-items a[href='/en/booster']", text: /Your daily capsule is ready/, visible: :all

    within("#booster-daily") { click_on "Collect" }

    assert_count 2
    assert_no_selector "#bell-items a[href='/en/booster']", visible: :all
    visit library_path(locale: :en)
    assert_count 2
  end

  test "on a 390 × 844 phone the top-level header carries the same bell and panel" do
    sign_in
    resize_to(*PHONE)
    visit library_path(locale: :en)

    within("header.top-bar--top-level") { assert_count 3 }
    open_bell
    within("#bell-panel") do
      assert_selector ".shell-popover__title", text: /what is new/i
      assert_link href: "/en/friends", text: /Max invites you to be friends/
    end
  ensure
    resize_to(*SCREEN_SIZE)
  end

  test "once every line is seen there is no count and the panel says nothing is new" do
    Game::DailyBonusClaim.create!(player_id: @hugo.id, day: Game::DailyBonusClaim.day_of(Time.current), pack_id: create_pack(@hugo, kind: :bonus).id)
    sign_in
    assert_count 2

    visit friends_path(locale: :en)
    assert_count 1
    visit social_path(locale: :en)
    assert_no_selector ".bell__count"
    assert_selector ".bell__button .visually-hidden", exact_text: "What is new, all seen", visible: :all
    open_bell
    within("#bell-panel") do
      assert_no_selector ".bell__line"
      assert_text "Nothing new for now."
    end
  end
end
