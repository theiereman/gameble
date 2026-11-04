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

  test "every tab is current on its own screens and on their drill-downs" do
    { home_path(locale: :en) => "/en", library_path(locale: :en) => "/en/library", library_cards_path(locale: :en) => "/en/library",
      social_path(locale: :en) => "/en/social", trades_path(locale: :en) => "/en/social", friends_path(locale: :en) => "/en/social",
      feed_path(locale: :en) => "/en/social" }.each do |path, tab|
      get path
      assert_response :success
      assert_select "a.tab-bar__tab[aria-current=page]", 1, path
      assert_select "a.tab-bar__tab[href='#{tab}'][aria-current=page]", 1, path
    end
  end

  test "the tabs start on the bridge, and the Me tab is gone" do
    get home_path(locale: :en)

    assert_equal %w[/en /en/booster /en/library /en/social], css_select(".tab-bar a.tab-bar__tab").pluck("href")
    assert_select ".tab-bar a.tab-bar__tab[href='/en'][aria-current=page] .tab-bar__label", "Bridge"
    assert_select ".tab-bar a.tab-bar__tab[href='/en/me']", false
  end

  test "every former More destination is one tap from Social, the Me page, the Sets switch or the header menu" do
    get home_path(locale: :en)
    reachable = css_select("#phone-menu-panel a[href]").pluck("href")
    [ social_path(locale: :en), me_path(locale: :en), library_path(locale: :en) ].each do |path|
      get path
      reachable.concat(css_select("main a[href]").pluck("href"))
    end

    assert_empty FORMER_MORE_DESTINATIONS - reachable
  end

  test "the Social home links trades, friends and the feed; the Me page the achievements" do
    get social_path(locale: :en)
    %w[/en/trades /en/friends /en/feed].each { assert_select ".social a.social__more[href='#{it}']" }

    get me_path(locale: :en)
    assert_select "main a.me-achievements__all[href='/en/achievements']"
  end

  test "the header menu opens the profile, how it works, the settings, then support and GitHub in a new tab" do
    get home_path(locale: :fr)

    assert_select ".top-bar .phone-menu button.phone-menu__button[popovertarget=phone-menu-panel]" do
      assert_select "svg.phone-menu__icon"
      assert_select ".visually-hidden", "Menu"
    end
    links = css_select("nav#phone-menu-panel.shell-popover[popover][aria-label=Menu] a.player-menu__item")
    assert_equal [ "/fr/me", "/fr/how-it-works", "/fr/settings", "https://buymeacoffee.com/theiereman", "https://github.com/theiereman/gameble" ],
      links.pluck("href")
    assert_equal [ "Mon profil", "Comment ça marche", "Paramètres", "Soutenir (nouvel onglet)", "GitHub (nouvel onglet)" ], links.map { it.text.squish }
    links.to_a.last(2).each do |link|
      assert_equal "_blank", link["target"]
      assert link.at_css("svg.menu-item__external")
    end
  end

  test "the Social tab holds the trades and invitations badge slots, the header menu the achievements one" do
    Game::Invitation.create!(sender_id: accounts_players(:moderator).id, recipient_id: @player.id)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)

    get home_path(locale: :en)

    assert_select ".tab-bar a.tab-bar__tab[href='/en/social'] #tab-trades-badge.stream-slot", 1
    assert_select ".tab-bar a.tab-bar__tab[href='/en/social'] #tab-invitations-badge.stream-slot .tab-bar__badge--friends", "1"
    assert_select ".phone-menu__button #phone-menu-badge.stream-slot .phone-menu__badge", "1"
    assert_select "#phone-menu-badge .visually-hidden", "1 reward to claim"
  end
end
