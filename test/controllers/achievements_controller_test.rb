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
    assert_select ".achievements__count[aria-hidden=true]", "3 / #{total_achievements}"
    assert_select ".achievements__head .visually-hidden", "3 succès obtenus sur #{total_achievements}"
    assert_select ".achievements__label", "Succès obtenus"
    assert_select ".achievements__gauge[aria-hidden=true] .achievements__segment", total_achievements
    assert_select ".achievements__segment--lit", 3
    assert_select "h2#achievements-earned", "Obtenus · 3"
    assert_select "h2#achievements-to_earn", "À obtenir · #{total_achievements - 3}"
    assert_equal [ "Première acquisition approuvée", "A surpassé les attentes", "Période d'essai validée" ], group_names(:earned)
    assert_equal [ "Nous n'en demandions pas autant", "Dossier complété", "Entraide mutuelle", "Historique de consommation exemplaire",
      "Loyauté au-delà du raisonnable", "Excellence administrative", "Contribution non rémunérée", "Non-conformité statistique",
      "Irrégularité de conditionnement", "L'excellence dans la médiocrité", "Gestion du patrimoine historique",
      "La chance est un concept marketing", "Demande de congé refusée", "Procédure d'ouverture simplifiée",
      "Zèle au-delà des obligations", "Portefeuille diversifié", "Concentration du marché", "Premier arrivé, premier servi",
      "Une découverte qui nous appartient", "Une relation strictement professionnelle" ], group_names(:to_earn)

    hundred = tile(:to_earn, "Historique de consommation exemplaire")
    assert_equal "Ouvrir 100 capsules", hundred.at_css(".achievement__condition").text
    bar = hundred.at_css("progress.achievement__bar[aria-hidden=true]")
    assert_equal [ "64", "100" ], [ bar["value"], bar["max"] ]
    assert_equal "64 / 100", hundred.at_css(".achievement__progress[aria-hidden=true]").text
    assert_equal "64 sur 100", hundred.at_css(".visually-hidden").text
    assert_equal "Ouvrir 500 capsules", tile(:to_earn, "Loyauté au-delà du raisonnable").at_css(".achievement__condition").text

    earned = tile(:earned, "Période d'essai validée")
    assert_nil earned.at_css("progress")
    assert_not earned["class"].include?("achievement--locked")
    assert earned.at_css("svg.pixel-icon.achievement__glyph")
    assert tile(:to_earn, "Entraide mutuelle")["class"].include?("achievement--locked")
    assert_select "[style]", false
  end

  test "a new player: nothing earned, every countable tile at zero" do
    sign_in(@player)

    get achievements_path(locale: :en)

    assert_select ".achievements__count", "0 / #{total_achievements}"
    assert_select ".achievements__head .visually-hidden", "0 achievements earned out of #{total_achievements}"
    assert_select ".achievements__label", "Achievements earned"
    assert_select ".achievements__segment--lit", 0
    assert_select "#achievements-earned", false
    assert_select "h2#achievements-to_earn", "To earn · #{total_achievements}"
    assert_equal [ [ "0", "10" ], [ "0", "100" ], [ "0", "500" ], [ "0", "3" ], [ "0", "10" ], [ "0", "7" ], [ "0", "10" ], [ "0", "10" ], [ "0", "5" ], [ "0", "10" ], [ "0", "3" ] ],
      css_select("progress.achievement__bar").map { [ it["value"], it["max"] ] }
    assert_equal [ "0 / 10", "0 / 100", "0 / 500", "0 / 3", "0 / 10", "0 / 7", "0 / 10", "0 / 10", "0 / 5", "0 / 10", "0 / 3" ], css_select(".achievement__progress").map(&:text)
    assert_equal "0 of 10", tile(:to_earn, "Probation Period Completed").at_css(".visually-hidden").text
    assert_equal "Open a capsule", tile(:to_earn, "Your First Authorized Acquisition").at_css(".achievement__condition").text
  end

  test "every achievement earned: a full gauge and no group to earn" do
    unlock(*Game::Achievements::CATALOGUE.map(&:key))
    sign_in(@player)

    get achievements_path(locale: :en)

    assert_select ".achievements__count", "#{total_achievements} / #{total_achievements}"
    assert_select ".achievements__segment--lit", total_achievements
    assert_select "h2#achievements-earned", "Earned · #{total_achievements}"
    assert_select "#achievements-to_earn", false
    assert_select "progress", false
  end

  test "Statistical Non-Compliance earned: its name, its condition and the outlier glyph in each locale" do
    unlock("statistical_non_compliance")
    sign_in(@player)
    outlier = Nokogiri::HTML5.fragment(ShellHelper.pixel_source("achievement-outlier")).at_css("svg").inner_html

    { en: [ "Statistical Non-Compliance", "Two Rare or better cards in one standard capsule" ],
      fr: [ "Non-conformité statistique", "Deux cartes Rares ou mieux dans une capsule standard" ] }.each do |locale, (name, condition)|
      get achievements_path(locale:)

      earned = tile(:earned, name)
      assert_equal condition, earned.at_css(".achievement__condition").text
      assert_equal outlier, earned.at_css("svg.achievement__glyph").inner_html
    end
  end

  test "the three one-capsule achievements: their names, conditions and glyphs in each locale, earned or not" do
    unlock("packaging_irregularity")
    sign_in(@player)
    glyph = ->(name) { Nokogiri::HTML5.fragment(ShellHelper.pixel_source(name)).at_css("svg").inner_html }

    { en: [ [ "Packaging Irregularity", "Two copies of the same game in one capsule", "duplicate" ],
            [ "Excellence in Mediocrity", "Five Common cards in one standard capsule", "tokens-locked" ],
            [ "Historical Asset Management", "A game released before 2000 and one released in 2025 or later in one capsule", "hourglass-locked" ] ],
      fr: [ [ "Irrégularité de conditionnement", "Deux exemplaires du même jeu dans une capsule", "duplicate" ],
            [ "L'excellence dans la médiocrité", "Cinq cartes Communes dans une capsule standard", "tokens-locked" ],
            [ "Gestion du patrimoine historique", "Un jeu sorti avant 2000 et un jeu sorti en 2025 ou après dans une même capsule", "hourglass-locked" ] ] }.each do |locale, tiles|
      get achievements_path(locale:)

      tiles.each_with_index do |(name, condition, icon), index|
        found = tile(index.zero? ? :earned : :to_earn, name)
        assert_equal condition, found.at_css(".achievement__condition").text
        assert_equal glyph.call("achievement-#{icon}"), found.at_css("svg.achievement__glyph").inner_html
        assert_nil found.at_css("progress")
      end
    end
  end

  test "the two collection achievements: their names, conditions and glyphs in each locale, earned or not" do
    unlock("diversified_portfolio")
    sign_in(@player)
    glyph = ->(name) { Nokogiri::HTML5.fragment(ShellHelper.pixel_source(name)).at_css("svg").inner_html }

    { en: [ [ "Diversified Portfolio", "Hold five copies of the same game at once", "fan" ],
            [ "Market Concentration", "Hold 10 different games of the same studio at once", "tower-locked" ] ],
      fr: [ [ "Portefeuille diversifié", "Détenir cinq exemplaires d'un même jeu en même temps", "fan" ],
            [ "Concentration du marché", "Détenir 10 jeux différents d'un même studio en même temps", "tower-locked" ] ] }.each do |locale, tiles|
      get achievements_path(locale:)

      tiles.each_with_index do |(name, condition, icon), index|
        found = tile(index.zero? ? :earned : :to_earn, name)
        assert_equal condition, found.at_css(".achievement__condition").text
        assert_equal glyph.call("achievement-#{icon}"), found.at_css("svg.achievement__glyph").inner_html
      end
    end
  end

  test "the three community achievements: their names, conditions and glyphs in each locale, earned or not" do
    unlock("first_claim_all_rights_reserved")
    sign_in(@player)
    glyph = ->(name) { Nokogiri::HTML5.fragment(ShellHelper.pixel_source(name)).at_css("svg").inner_html }

    { en: [ [ "First Claim, All Rights Reserved", "Be the pioneer of a card in a season", "flag" ],
            [ "A Discovery of Ours", "Repost a card you pioneered", "lens-locked" ],
            [ "A Strictly Professional Relationship", "Complete three trades with the same player", "clasp-locked" ] ],
      fr: [ [ "Premier arrivé, premier servi", "Être le pionnier d'une carte dans une saison", "flag" ],
            [ "Une découverte qui nous appartient", "Reposter une carte dont vous êtes le pionnier", "lens-locked" ],
            [ "Une relation strictement professionnelle", "Conclure trois échanges avec le même joueur", "clasp-locked" ] ] }.each do |locale, tiles|
      get achievements_path(locale:)

      tiles.each_with_index do |(name, condition, icon), index|
        found = tile(index.zero? ? :earned : :to_earn, name)
        assert_equal condition, found.at_css(".achievement__condition").text
        assert_equal glyph.call("achievement-#{icon}"), found.at_css("svg.achievement__glyph").inner_html
      end
    end
  end

  test "the two streak achievements: their names, conditions and glyphs in each locale, earned or not" do
    unlock("luck_is_a_marketing_concept")
    sign_in(@player)
    glyph = ->(name) { Nokogiri::HTML5.fragment(ShellHelper.pixel_source(name)).at_css("svg").inner_html }

    { en: [ [ "Luck Is a Marketing Concept", "10 standard capsules in a row with no Rare or better card", "clover" ],
            [ "Leave Request Denied", "Collect the daily bonus 7 days in a row (UTC days)", "refused-locked" ] ],
      fr: [ [ "La chance est un concept marketing", "10 capsules standard de suite sans carte Rare ou mieux", "clover" ],
            [ "Demande de congé refusée", "Récupérer le bonus quotidien 7 jours de suite (jours UTC)", "refused-locked" ] ] }.each do |locale, tiles|
      get achievements_path(locale:)

      tiles.each_with_index do |(name, condition, icon), index|
        found = tile(index.zero? ? :earned : :to_earn, name)
        assert_equal condition, found.at_css(".achievement__condition").text
        assert_equal glyph.call("achievement-#{icon}"), found.at_css("svg.achievement__glyph").inner_html
      end
    end
  end

  test "the two reveal streak achievements: their names, conditions and glyphs in each locale, earned or not" do
    unlock("streamlined_opening_procedure")
    sign_in(@player)
    glyph = ->(name) { Nokogiri::HTML5.fragment(ShellHelper.pixel_source(name)).at_css("svg").inner_html }

    { en: [ [ "Streamlined Opening Procedure", "10 capsules in a row opened with \"Reveal all\"", "skip" ],
            [ "Diligence Beyond the Call of Duty", "10 capsules in a row with every card revealed one by one", "revealed-locked" ] ],
      fr: [ [ "Procédure d'ouverture simplifiée", "10 capsules de suite ouvertes avec « Tout révéler »", "skip" ],
            [ "Zèle au-delà des obligations", "10 capsules de suite dont chaque carte est révélée une à une", "revealed-locked" ] ] }.each do |locale, tiles|
      get achievements_path(locale:)

      tiles.each_with_index do |(name, condition, icon), index|
        found = tile(index.zero? ? :earned : :to_earn, name)
        assert_equal condition, found.at_css(".achievement__condition").text
        assert_equal glyph.call("achievement-#{icon}"), found.at_css("svg.achievement__glyph").inner_html
      end
    end
  end

  test "the tiles that unlock a card back name it with its picture, earned or not" do
    unlock("boosters_100")
    sign_in(@player)

    get achievements_path(locale: :fr)

    centurion = tile(:earned, "Historique de consommation exemplaire")
    assert_equal "Débloque le dos Centurion", centurion.at_css(".achievement__back").text.strip
    assert centurion.at_css("img.achievement__back-image")
    assert_equal "Débloque le dos Étoile d'or", tile(:to_earn, "Nous n'en demandions pas autant").at_css(".achievement__back").text.strip
    assert_equal "Débloque le dos Aurore", tile(:to_earn, "Excellence administrative").at_css(".achievement__back").text.strip
    assert_nil tile(:to_earn, "Loyauté au-delà du raisonnable").at_css(".achievement__back")
    assert_nil tile(:to_earn, "Entraide mutuelle").at_css(".achievement__back")
  end

  test "the four hardest achievements show the back they unlock, with its picture" do
    sign_in(@player)
    { "luck_is_a_marketing_concept" => "Wilted clover", "leave_request_denied" => "Assiduous",
      "market_concentration" => "Headquarters", "a_strictly_professional_relationship" => "Contract" }.each do |key, back|
      get achievements_path(locale: :en)
      found = tile(:to_earn, I18n.t("achievements.names.#{key}", locale: :en))

      assert_equal "Unlocks the #{back} card back", found.at_css(".achievement__back").text.strip
      assert found.at_css("img.achievement__back-image")
    end
  end

  test "the card back line reads in English" do
    sign_in(@player)

    get achievements_path(locale: :en)

    assert_equal "Unlocks the Dawn card back", tile(:to_earn, "Archival Excellence").at_css(".achievement__back").text.strip
  end

  test "an achievement of threshold one not yet earned shows no bar nor count" do
    sign_in(@player)

    get achievements_path(locale: :fr)

    trade = tile(:to_earn, "Entraide mutuelle")
    assert_equal "Conclure un échange", trade.at_css(".achievement__condition").text
    assert_nil trade.at_css("progress")
    assert_nil trade.at_css(".achievement__progress")
  end

  test "a met achievement waiting for its grant stays to earn, its bar full" do
    opened_packs(12)
    sign_in(@player)

    get achievements_path(locale: :fr)

    ten = tile(:to_earn, "Période d'essai validée")
    bar = ten.at_css("progress")
    assert_equal [ "10", "10" ], [ bar["value"], bar["max"] ]
    assert_equal "10 / 10", ten.at_css(".achievement__progress").text
  end

  test "a visitor is sent to the landing" do
    get achievements_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]
  end

  test "on the phone the screen sits under the PLUS tab, with a way back to it" do
    sign_in(@player)

    get achievements_path(locale: :fr)

    assert_select "a.tab-bar__tab[href='/fr/more'][aria-current=page]", /Plus/
    assert_select ".top-bar a.top-bar__phone-back[href='/fr/more']", /Plus/
  end

  test "menu 07 and the PLUS row lead a player to the achievements, with the count earned" do
    unlock("first_booster", "first_trade", "first_repost")
    sign_in(@player)

    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/achievements'][aria-keyshortcuts='7']" do
      assert_select ".menu-item__label", "Succès"
      assert_select ".menu-item__meta[aria-hidden=true]", "3/#{total_achievements}"
      assert_select ".visually-hidden", "3 succès obtenus sur #{total_achievements}"
    end
    get home_path(locale: :en)
    assert_select ".hub-menu a.menu-item[href='/en/achievements'] .visually-hidden", "3 achievements earned out of #{total_achievements}"
    get more_path(locale: :fr)
    assert_select ".plus__list a.menu-item[href='/fr/achievements']", /Succès/
  end

  def total_achievements = Game::Achievements::CATALOGUE.size
end
