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

  test "the tabs read Bridge, Capsule, Sets, Friends and Trades, and the Me tab is gone" do
    get home_path(locale: :en)

    assert_equal %w[/en /en/booster /en/library /en/friends /en/trades], css_select(".tab-bar a.tab-bar__tab").pluck("href")
    assert_equal %w[Bridge Capsule Sets Friends Trades], css_select(".tab-bar .tab-bar__label").map(&:text)
    assert_select ".tab-bar a.tab-bar__tab[href='/en'][aria-current=page]"
  end

  test "every tab is current on its own screens and on their drill-downs" do
    { home_path(locale: :en) => "/en", library_path(locale: :en) => "/en/library", library_cards_path(locale: :en) => "/en/library",
      trades_path(locale: :en) => "/en/trades", friends_path(locale: :en) => "/en/friends",
      feed_path(locale: :en) => "/en/friends" }.each do |path, tab|
      get path
      assert_response :success
      assert_select "a.tab-bar__tab[aria-current=page]", 1, path
      assert_select "a.tab-bar__tab[href='#{tab}'][aria-current=page]", 1, path
    end
  end

  test "every former More destination is a tab, or one tap from Friends, the Me page, the Sets switch or the header menu" do
    get home_path(locale: :en)
    reachable = css_select("#phone-menu-panel a[href], .tab-bar a[href]").pluck("href")
    [ friends_path(locale: :en), me_path(locale: :en), library_path(locale: :en) ].each do |path|
      get path
      reachable.concat(css_select("main a[href]").pluck("href"))
    end

    assert_empty FORMER_MORE_DESTINATIONS - reachable
  end

  test "Trades and Friends are tab roots with no back button, the feed goes back to Friends on the phone" do
    [ trades_path(locale: :en), friends_path(locale: :en) ].each do |path|
      get path
      assert_select ".top-bar__phone-back", 0, path
    end

    get feed_path(locale: :en)
    back = css_select(".top-bar__start > a.top-bar__phone-back").sole
    assert_equal [ "/en/friends", "Friends" ], [ back["href"], back.at_css(".button__label").text ]
  end

  test "the Friends screen links the activity feed; the Me page the achievements" do
    get friends_path(locale: :fr)
    assert_select ".friends__feed a[href='/fr/feed']", "Fil d'activité"

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

  test "the Trades tab holds the trades badge slot, the Friends tab the invitations one, the header menu the achievements one" do
    Game::Invitation.create!(sender_id: accounts_players(:moderator).id, recipient_id: @player.id)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)

    get home_path(locale: :en)

    assert_select ".tab-bar a.tab-bar__tab[href='/en/trades'] #tab-trades-badge.stream-slot", 1
    assert_select ".tab-bar a.tab-bar__tab[href='/en/friends'] #tab-invitations-badge.stream-slot .tab-bar__badge--friends", "1"
    assert_select ".phone-menu__button #phone-menu-badge.stream-slot .phone-menu__badge", "1"
    assert_select "#phone-menu-badge .visually-hidden", "1 reward to claim"
  end
end
