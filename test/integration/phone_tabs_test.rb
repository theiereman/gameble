require "test_helper"
require_relative "../support/steam_sign_in"

# The phone's four tabs, the Social home and the Me page behind two of them, and the
# Sets | All cards switch.
class PhoneTabsTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  FORMER_MORE_DESTINATIONS = %w[
    /en/library/cards /en/trades /en/friends /en/feed /en/achievements /en/settings /en/how-it-works
  ].freeze

  setup do
    @player = accounts_players(:player)
    sign_in(@player)
  end

  test "the old More address redirects for good to the Me page in the same locale" do
    get more_path(locale: :en)

    assert_redirected_to "/en/me"
    assert_response :moved_permanently
  end

  test "every tab is current on its own screens and on their drill-downs" do
    { library_path(locale: :en) => "/en/library", library_cards_path(locale: :en) => "/en/library",
      social_path(locale: :en) => "/en/social", trades_path(locale: :en) => "/en/social", friends_path(locale: :en) => "/en/social",
      feed_path(locale: :en) => "/en/social", me_path(locale: :en) => "/en/me", settings_path(locale: :en) => "/en/me",
      achievements_path(locale: :en) => "/en/me", how_it_works_path(locale: :en) => "/en/me" }.each do |path, tab|
      get path
      assert_response :success
      assert_select "a.tab-bar__tab[aria-current=page]", 1, path
      assert_select "a.tab-bar__tab[href='#{tab}'][aria-current=page]", 1, path
    end
  end

  test "every former More destination is one tap from Social or Me, or from the Sets switch" do
    reachable = []
    [ social_path(locale: :en), me_path(locale: :en), library_path(locale: :en) ].each do |path|
      get path
      reachable.concat(css_select("main a[href]").pluck("href"))
    end

    assert_empty FORMER_MORE_DESTINATIONS - reachable
  end

  test "the Social home links trades, friends and the feed; the Me page the achievements, how it works and the settings" do
    get social_path(locale: :en)
    assert_select ".plus__list", false
    %w[/en/trades /en/friends /en/feed].each { assert_select ".social a.social__more[href='#{it}']" }

    get me_path(locale: :en)
    assert_select "main a.menu-item[href='/en/achievements']"
    assert_select ".plus__list > li", 2
    %w[/en/how-it-works /en/settings].each { assert_select ".plus__list a.menu-item[href='#{it}']" }
  end

  test "the Social tab holds the trades and invitations badge slots, the Me tab the achievements one" do
    Game::Invitation.create!(sender_id: accounts_players(:moderator).id, recipient_id: @player.id)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)

    get home_path(locale: :en)

    assert_select ".tab-bar a.tab-bar__tab[href='/en/social'] #tab-trades-badge.stream-slot", 1
    assert_select ".tab-bar a.tab-bar__tab[href='/en/social'] #tab-invitations-badge.stream-slot .tab-bar__badge--alert", "1"
    assert_select ".tab-bar a.tab-bar__tab[href='/en/me'] #tab-me-badge.stream-slot .tab-bar__badge--alert", "1"
    assert_select "#tab-me-badge .visually-hidden", "1 reward to claim"
  end
end
