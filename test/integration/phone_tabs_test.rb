require "test_helper"
require_relative "../support/steam_sign_in"

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

  test "the old Social address redirects to the Friends screen in the same locale" do
    get social_path(locale: :fr)

    assert_redirected_to "/fr/friends"
  end

  test "the tabs read Bridge, Capsule, Sets, Trades and Market" do
    get home_path(locale: :en)

    assert_equal %w[/en /en/booster /en/library /en/trades /en/market], css_select(".tab-bar a.tab-bar__tab").pluck("href")
    assert_equal %w[Bridge Capsule Sets Trades Market], css_select(".tab-bar .tab-bar__label").map(&:text)
    assert_select ".tab-bar a.tab-bar__tab[href='/en'][aria-current=page]"
  end

  test "every tab is current on its own screens and on their drill-downs" do
    { home_path(locale: :en) => "/en", library_path(locale: :en) => "/en/library", library_cards_path(locale: :en) => "/en/library",
      trades_path(locale: :en) => "/en/trades", market_path(locale: :en) => "/en/market",
      feed_path(locale: :en) => "/en", fortune_register_path(locale: :en) => "/en" }.each do |path, tab|
      get path
      assert_response :success
      assert_select "a.tab-bar__tab[aria-current=page]", 1, path
      assert_select "a.tab-bar__tab[href='#{tab}'][aria-current=page]", 1, path
    end
  end

  test "every former More destination is a tab, or one tap from the bridge, Friends, the Me page, the Sets switch, the player menu or the settings" do
    get home_path(locale: :en)
    reachable = css_select("#player-menu a[href], .tab-bar a[href]").pluck("href")
    [ home_path(locale: :en), friends_path(locale: :en), me_path(locale: :en), library_path(locale: :en), settings_path(locale: :en) ].each do |path|
      get path
      reachable.concat(css_select("main a[href]").pluck("href"))
    end

    assert_empty FORMER_MORE_DESTINATIONS - reachable
  end

  test "Trades and the market are tab roots with no back button, Friends leaves the roots, the feed goes back to the bridge on the phone" do
    [ trades_path(locale: :en), market_path(locale: :en) ].each do |path|
      get path
      assert_select ".top-bar__phone-back", 0, path
      assert_select ".top-bar--top-level", 1, path
    end

    get friends_path(locale: :en)
    assert_select ".top-bar--top-level", 0

    get feed_path(locale: :en)
    back = css_select(".top-bar__start > a.top-bar__phone-back").sole
    assert_equal [ "/en", "Bridge" ], [ back["href"], back.at_css(".button__label").text ]
  end

  test "the bridge previews the activity feed and opens it, Friends no longer does; the Me page links the achievements" do
    get home_path(locale: :fr)
    assert_select ".hub__aside .live-strip.live-strip--stacked[aria-labelledby=hub-live]" do
      assert_select "#hub-live", /Fil d'activité/
      assert_select "#live-strip"
      assert_select ".live-strip__open a.button--link[href='/fr/feed']", "Ouvrir le fil"
    end
    assert_select ".hub__aside turbo-cable-stream-source", 0

    get friends_path(locale: :fr)
    assert_select "main a[href='/fr/feed']", 0

    get me_path(locale: :en)
    assert_select "main a.me-achievements__all[href='/en/achievements']"
  end

  test "one menu under the avatar: me, friends, settings, support, and the sign-out at its foot; how it works and the code live in the settings" do
    get home_path(locale: :fr)

    assert_select ".phone-menu", 0
    links = css_select("nav#player-menu.shell-popover[popover] a.player-menu__item")
    assert_equal [ "/fr/me", "/fr/friends", "/fr/settings", "https://buymeacoffee.com/theiereman" ], links.pluck("href")
    assert_equal "Mon profil", links.first.text.squish
    assert_equal "Amis 0 en ligne", links[1].text.squish
    assert_equal "Soutenir (nouvel onglet)", links.last.text.squish
    assert_select "#player-menu li:last-child form button.player-menu__item", "Se déconnecter"

    get settings_path(locale: :fr)
    assert_select "main a.button--link[href='/fr/how-it-works']", "Comment ça marche"
    assert_select "main a.button--link[href='https://github.com/theiereman/gameble'][target=_blank]"
  end

  test "the avatar carries one badge summing what waits, each line its own detail; the Trades tab keeps its badge" do
    Game::Invitation.create!(sender_id: accounts_players(:moderator).id, recipient_id: @player.id)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)

    get home_path(locale: :en)

    assert_select ".tab-bar a.tab-bar__tab[href='/en/trades'] #tab-trades-badge.stream-slot", 1
    assert_select ".player-chip__button #player-menu-badge.stream-slot .player-chip__badge", "2"
    assert_select "#player-menu-badge .visually-hidden", "2 things waiting for you"
    assert_select "#player-menu a[href='/en/friends'] #player-menu-invitations-badge.stream-slot .menu-item__badge--friends", "1"
    assert_select "#player-menu a[href='/en/me'] #player-menu-achievements-badge.stream-slot .menu-item__badge--alert", "1"
    assert_select "#player-menu-achievements-badge .visually-hidden", "1 reward to claim"
  end
end
