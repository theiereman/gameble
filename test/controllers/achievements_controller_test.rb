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
    keys.each { |key| Game::AchievementUnlock.create!(player_id: @player.id, achievement: key, unlocked_at: Time.current, collected_at: Time.current) }
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
    assert_equal [ "Première capsule", "Première Épique", "10 capsules" ], group_names(:earned)
    assert_equal [ "Première Légendaire", "Premier set complet", "Premier échange", "100 capsules", "500 capsules",
      "Trois sets complets", "Premier repost" ], group_names(:to_earn)

    hundred = tile(:to_earn, "100 capsules")
    assert_equal "Ouvrir 100 capsules", hundred.at_css(".achievement__condition").text
    bar = hundred.at_css("progress.achievement__bar[aria-hidden=true]")
    assert_equal [ "64", "100" ], [ bar["value"], bar["max"] ]
    assert_equal "64 / 100", hundred.at_css(".achievement__progress[aria-hidden=true]").text
    assert_equal "64 sur 100", hundred.at_css(".visually-hidden").text
    assert_equal "Ouvrir 500 capsules", tile(:to_earn, "500 capsules").at_css(".achievement__condition").text

    earned = tile(:earned, "10 capsules")
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
    assert_equal "0 of 10", tile(:to_earn, "10 capsules").at_css(".visually-hidden").text
    assert_equal "Open a capsule", tile(:to_earn, "First capsule").at_css(".achievement__condition").text
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

  test "the tiles that unlock a card back name it with its picture, earned or not" do
    unlock("boosters_100")
    sign_in(@player)

    get achievements_path(locale: :fr)

    centurion = tile(:earned, "100 capsules")
    assert_equal "Débloque le dos Centurion", centurion.at_css(".achievement__back").text.strip
    assert centurion.at_css("img.achievement__back-image")
    assert_equal "Débloque le dos Étoile d'or", tile(:to_earn, "Première Légendaire").at_css(".achievement__back").text.strip
    assert_equal "Débloque le dos Aurore", tile(:to_earn, "Trois sets complets").at_css(".achievement__back").text.strip
    assert_nil tile(:to_earn, "500 capsules").at_css(".achievement__back")
    assert_nil tile(:to_earn, "Premier échange").at_css(".achievement__back")
  end

  test "the card back line reads in English" do
    sign_in(@player)

    get achievements_path(locale: :en)

    assert_equal "Unlocks the Dawn card back", tile(:to_earn, "Three complete sets").at_css(".achievement__back").text.strip
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

    ten = tile(:to_earn, "10 capsules")
    bar = ten.at_css("progress")
    assert_equal [ "10", "10" ], [ bar["value"], bar["max"] ]
    assert_equal "10 / 10", ten.at_css(".achievement__progress").text
  end

  test "a visitor is sent to the landing" do
    get achievements_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]
  end

  test "on the phone the screen belongs to the own profile, with a way back to it" do
    sign_in(@player)

    get achievements_path(locale: :fr)

    assert_select "a.tab-bar__tab[aria-current]", false
    assert_select ".top-bar a.top-bar__phone-back[href=?]", "/fr/brothers/#{@player.token}", text: /Profil/
  end

  test "menu 07 leads a player to the achievements, with the count earned, and PLUS no longer lists them" do
    unlock("first_booster", "first_trade", "first_repost")
    sign_in(@player)

    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/achievements'][aria-keyshortcuts='7']" do
      assert_select ".menu-item__label", "Succès"
      assert_select ".menu-item__meta[aria-hidden=true]", "3/10"
      assert_select ".visually-hidden", "3 succès obtenus sur 10"
    end
    get home_path(locale: :en)
    assert_select ".hub-menu a.menu-item[href='/en/achievements'] .visually-hidden", "3 achievements earned out of 10"
    get more_path(locale: :fr)
    assert_select ".plus__list a.menu-item[href='/fr/achievements']", false
  end

  def reach(*keys)
    keys.each { |key| Game::AchievementUnlock.record(@player.id, key, Time.current) }
  end

  test "a reached achievement waits first, in its own group, with a Collect button that posts to its key" do
    reach("first_trade")
    unlock("first_booster")
    sign_in(@player)

    get achievements_path(locale: :fr)

    assert_equal %w[achievements-ready achievements-earned achievements-to_earn], css_select(".achievements__group > h2").map { it["id"] }
    assert_select "h2#achievements-ready", "À récupérer · 1"
    assert_select ".achievements__count", "1 / 10"
    ready = tile(:ready, "Premier échange")
    assert ready["class"].include?("achievement--ready")
    assert_not ready["class"].include?("achievement--locked")
    form = ready.at_css("form.achievement__collect-form[action='/fr/achievements/first_trade/collect'][data-turbo=false]")
    assert form
    assert_equal [ "Récupérer", "Récupérer Premier échange" ], [ form.at_css("button").text.strip, form.at_css("button")["aria-label"] ]
    assert_nil tile(:earned, "Première capsule").at_css("form")
  end

  test "collecting moves the achievement to the earned group with a toast; a second click is refused" do
    reach("first_trade")
    sign_in(@player)

    post collect_achievement_path(locale: :en, key: "first_trade")

    assert_redirected_to achievements_path(locale: :en)
    assert_equal [ "Achievement collected", "First trade" ], [ flash[:toast_title], flash[:notice] ]
    follow_redirect!
    assert_select "#achievements-ready", false
    assert_equal [ "First trade" ], group_names(:earned)

    post collect_achievement_path(locale: :en, key: "first_trade")
    assert_equal I18n.t("errors.game.not_ready", locale: :en), flash[:alert]
  end

  test "an achievement not reached cannot be collected, and a visitor is sent to the landing" do
    sign_in(@player)
    post collect_achievement_path(locale: :fr, key: "first_trade")
    assert_equal I18n.t("errors.game.not_ready", locale: :fr), flash[:alert]
    assert_nil Game::AchievementUnlock.find_by(player_id: @player.id, achievement: "first_trade")

    delete session_path(locale: :en)
    post collect_achievement_path(locale: :fr, key: "first_trade")
    assert_redirected_to home_path(locale: :fr)
  end

  test "the own profile's achievements button rings with the count to collect; a visitor's view has no button" do
    reach("first_trade", "first_epic")
    unlock("first_booster")
    sign_in(@player)

    get brother_path(locale: :en, token: @player.token)

    assert_select "#profile-achievements-heading + a.profile-achievements__open[href='/en/achievements']" do
      assert_select "svg.pixel-icon"
      assert_select ".button__label", "Achievements"
      assert_select ".profile-achievements__badge[aria-hidden=true]", "2"
      assert_select ".visually-hidden", "2 achievements to collect"
    end
    assert_select ".profile-band__keys .profile-figure", /1\s*\/\s*10/

    sign_in(accounts_players(:moderator))
    get brother_path(locale: :en, token: @player.token)
    assert_select ".profile-achievements__open", false
  end
end
