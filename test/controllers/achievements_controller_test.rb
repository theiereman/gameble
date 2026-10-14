require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class AchievementsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def unlock(*keys)
    keys.each { |key| Game::AchievementUnlock.create!(player_id: @player.id, achievement: key, unlocked_at: Time.current) }
  end

  def opened_packs(count)
    count.times { create_pack(@player, opened_at: Time.current) }
  end

  def tile(group, name)
    css_select("#achievements-#{group} + .achievements__grid .achievement").find { it.at_css(".achievement__name").text == name }
  end

  def group_names(group)
    css_select("#achievements-#{group} + .achievements__grid .achievement__name").map(&:text)
  end

  test "a player with some earned: the count, the lit segments, both groups and a bar on a countable tile" do
    unlock("first_booster", "first_epic", "boosters_10")
    opened_packs(64)
    sign_in(@player)

    get achievements_path(locale: :fr)

    assert_response :success
    assert_select "title", /Succès/
    assert_select "header.top-bar[data-screen-label=Succès]"
    assert_select ".top-bar__title", "Succès"
    assert_select "main h1", "Succès"
    assert_select ".achievements__count[aria-hidden=true]", "3 / 10"
    assert_select ".achievements__head .visually-hidden", "3 succès obtenus sur 10"
    assert_select ".achievements__label", "Succès obtenus"
    assert_select ".achievements__gauge[aria-hidden=true] .achievements__segment", 10
    assert_select ".achievements__segment--lit", 3
    assert_select "h2#achievements-earned", "Obtenus · 3"
    assert_select "h2#achievements-to_earn", "À obtenir · 7"
    assert_equal [ "Premier booster", "Première Épique", "10 boosters" ], group_names(:earned)
    assert_equal [ "Première Légendaire", "Premier set complet", "Premier échange", "100 boosters", "500 boosters",
      "Trois sets complets", "Premier repost" ], group_names(:to_earn)

    hundred = tile(:to_earn, "100 boosters")
    assert_equal "Ouvrir 100 boosters", hundred.at_css(".achievement__condition").text
    bar = hundred.at_css("progress.achievement__bar[aria-hidden=true]")
    assert_equal [ "64", "100" ], [ bar["value"], bar["max"] ]
    assert_equal "64 / 100", hundred.at_css(".achievement__progress[aria-hidden=true]").text
    assert_equal "64 sur 100", hundred.at_css(".visually-hidden").text
    assert_equal "Ouvrir 500 boosters", tile(:to_earn, "500 boosters").at_css(".achievement__condition").text

    earned = tile(:earned, "10 boosters")
    assert_nil earned.at_css("progress")
    assert_not earned["class"].include?("achievement--locked")
    assert earned.at_css("svg.pixel-icon.achievement__glyph")
    assert tile(:to_earn, "Premier échange")["class"].include?("achievement--locked")
    assert_select "[style]", false
  end

  test "a new player: nothing earned, every countable tile at zero" do
    sign_in(@player)

    get achievements_path(locale: :en)

    assert_select ".achievements__count", "0 / 10"
    assert_select ".achievements__head .visually-hidden", "0 achievements earned out of 10"
    assert_select ".achievements__label", "Achievements earned"
    assert_select ".achievements__segment--lit", 0
    assert_select "#achievements-earned", false
    assert_select "h2#achievements-to_earn", "To earn · 10"
    assert_equal [ [ "0", "10" ], [ "0", "100" ], [ "0", "500" ], [ "0", "3" ] ],
      css_select("progress.achievement__bar").map { [ it["value"], it["max"] ] }
    assert_equal [ "0 / 10", "0 / 100", "0 / 500", "0 / 3" ], css_select(".achievement__progress").map(&:text)
    assert_equal "0 of 10", tile(:to_earn, "10 boosters").at_css(".visually-hidden").text
    assert_equal "Open a booster", tile(:to_earn, "First booster").at_css(".achievement__condition").text
  end

  test "every achievement earned: a full gauge and no group to earn" do
    unlock(*Game::Achievements::CATALOGUE.map(&:key))
    sign_in(@player)

    get achievements_path(locale: :en)

    assert_select ".achievements__count", "10 / 10"
    assert_select ".achievements__segment--lit", 10
    assert_select "h2#achievements-earned", "Earned · 10"
    assert_select "#achievements-to_earn", false
    assert_select "progress", false
  end

  test "an achievement of threshold one not yet earned shows no bar nor count" do
    sign_in(@player)

    get achievements_path(locale: :fr)

    trade = tile(:to_earn, "Premier échange")
    assert_equal "Conclure un échange", trade.at_css(".achievement__condition").text
    assert_nil trade.at_css("progress")
    assert_nil trade.at_css(".achievement__progress")
  end

  test "a met achievement waiting for its grant stays to earn, its bar full" do
    opened_packs(12)
    sign_in(@player)

    get achievements_path(locale: :fr)

    ten = tile(:to_earn, "10 boosters")
    bar = ten.at_css("progress")
    assert_equal [ "10", "10" ], [ bar["value"], bar["max"] ]
    assert_equal "10 / 10", ten.at_css(".achievement__progress").text
  end

  test "a visitor is sent home to sign in" do
    get achievements_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]
  end

  test "on the phone the screen sits under the PLUS tab, with a way back to it" do
    sign_in(@player)

    get achievements_path(locale: :fr)

    assert_select "a.tab-bar__tab[href='/fr/more'][aria-current=page]", /Plus/
    assert_select ".top-bar a.top-bar__phone-back[href='/fr/more']", /Plus/
  end

  test "menu 06 and the PLUS row lead a player to the achievements, with the count earned" do
    unlock("first_booster", "first_trade", "first_repost")
    sign_in(@player)

    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/achievements'][aria-keyshortcuts='6']" do
      assert_select ".menu-item__label", "Succès"
      assert_select ".menu-item__meta[aria-hidden=true]", "3/10"
      assert_select ".visually-hidden", "3 succès obtenus sur 10"
    end
    get home_path(locale: :en)
    assert_select ".hub-menu a.menu-item[href='/en/achievements'] .visually-hidden", "3 achievements earned out of 10"
    get more_path(locale: :fr)
    assert_select ".plus__list a.menu-item[href='/fr/achievements']", /Succès/
  end

  test "menu 06 and the PLUS row open the sign-in panel for a visitor" do
    get home_path(locale: :fr)
    assert_select ".hub-menu button.menu-item[aria-keyshortcuts='6'][aria-haspopup=dialog][data-dialog-opener-dialog-value=sign-in-panel]", /Succès/
    assert_select ".hub-menu [aria-keyshortcuts='6'] .menu-item__meta", false
    get more_path(locale: :en)
    assert_select ".plus__list button.menu-item[aria-haspopup=dialog][data-dialog-opener-dialog-value=sign-in-panel]", /Achievements/
    assert_select ".plus__list a[href='/en/achievements']", false
  end
end
