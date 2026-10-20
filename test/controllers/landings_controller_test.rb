require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/catalog_seeds"

class LandingsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include CatalogSeeds

  MODULES = %w[concept brotherhood how live unlock roadmap open_source free boarding].freeze

  def heading_name(key, locale)
    "#{I18n.t("landings.show.#{key}.label", locale:)}, #{I18n.t("landings.show.#{key}.title", locale:)}"
  end

  def assert_headings(locale)
    assert_select "h1", 1
    assert_select "h1", I18n.t("landings.show.hero.hook", locale:)
    headings = css_select("main h2").map { it.text.squish }
    assert_equal MODULES.map { heading_name(it, locale) }, headings
    MODULES.each_with_index { |key, index| assert headings[index].start_with?("0#{index + 1} · ") }
    assert_select "main section[aria-label], main section[aria-labelledby]", 0
    assert_select "main h3", 2
    assert_select "main h3", I18n.t("landings.show.open_source.recruiting", locale:)
    assert_select "main h3", I18n.t("landings.show.free.support.line", locale:)
    assert_select "main h4", 3
  end

  def concept_faces
    css_select(".landing-rarities li").map { it.at_css(".card .card__title")&.text }
  end

  def concept_rarities
    css_select(".landing-rarities li").map { it["data-tier"] }
  end

  test "a visitor reads the landing in French: one h1, the nine modules, the five rarities with their odds" do
    get landing_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_headings(:fr)
    assert_equal %w[common uncommon rare epic legendary], concept_rarities
    assert_equal [ "Soldat de plomb", "Collines vertes", "Profondeurs bleues", "Portal", "Couronne d'or" ], concept_faces
    assert_select ".landing-rarities[aria-label=?]", I18n.t("landings.show.concept.cards_label", locale: :fr)
    assert_select ".landing-rarities li .landing-rarity__odds", text: "76 % par carte"
    assert_select ".landing-rarities li .landing-rarity__odds", text: "0,05 % par carte"
    assert_select ".landing-rarity__name", text: "Légendaire"
  end

  test "a visitor reads the landing in English" do
    get landing_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_headings(:en)
    assert_equal [ "Tin Soldier", "Green Hills", "Blue Depths", "Portal", "Golden Crown" ], concept_faces
    assert_select ".landing-rarities li .landing-rarity__odds", text: "4.3% per card"
  end

  test "the reveal demo holds every sample face, hidden, with its announcement, and a hidden button" do
    get landing_path(locale: :fr)

    faces = css_select("[data-controller=reveal-demo] [data-reveal-demo-target=face]")
    assert_equal 5, faces.size
    assert faces.all? { it.attribute("hidden") }
    assert_equal "Carte révélée : Portal — Valve, 2007. Épique.", faces[3]["data-announcement"]
    assert_equal "Carte révélée : Soldat de plomb — 2024. Commune.", faces[0]["data-announcement"]
    assert_select "[data-controller=reveal-demo] button[hidden][data-action='reveal-demo#toggle']", "Révéler"
    assert_select "[data-controller=reveal-demo] [role=status]", 1
  end

  test "of two cards of a rarity, the one with the higher prestige score is shown" do
    seed_card_seasons([ 0.95 ], season: catalog_seasons(:one), prefix: "bright", titles: [ "Bright Star" ])
    Catalog::CardSeason.joins(:card).where(catalog_cards: { slug: "bright-1-0" }).update_all(rarity: 4)

    get landing_path(locale: :en)

    assert_equal [ "Tin Soldier", "Green Hills", "Blue Depths", "Bright Star", "Golden Crown" ], concept_faces
  end

  test "a rarity without a card shows the card back face down, its name and odds still" do
    Catalog::CardSeason.where(id: catalog_card_seasons(:legendary_card_one).id).delete_all

    get landing_path(locale: :en)

    assert_response :success
    assert_equal [ "Tin Soldier", "Green Hills", "Blue Depths", "Portal", nil ], concept_faces
    assert_select ".landing-rarity--legendary img.landing-card-back[alt='']", 1
    assert_select ".landing-rarity--legendary .landing-rarity__odds", "0.05% per card"
    assert_select ".landing-rarity--legendary .landing-rarity__name", "Legendary"
    assert_equal 4, css_select("[data-reveal-demo-target=face]").size
  end

  test "without a published season every slot is face down, the odds stay, and there is no demo button" do
    Catalog::Season.update_all(status: "draft", published_at: nil)

    get landing_path(locale: :fr)

    assert_response :success
    assert_headings(:fr)
    assert_select ".landing-rarities li", 5
    assert_select ".landing-rarities .card", 0
    assert_select ".landing-rarities img.landing-card-back", 5
    assert_select ".landing-rarities .landing-rarity__odds", 5
    assert_select "[data-reveal-demo-target=face]", 0
    assert_select "[data-controller=reveal-demo] button", 0
    assert_select ".landing-thumb[data-controller=card-art]", 0
    assert_select ".landing-thumb--empty"
  end

  test "a signed-in player is sent to the hub" do
    sign_in(accounts_players(:player))

    get landing_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
    assert_response :see_other
  end

  test "no inline style, no script without a nonce, no database id" do
    get landing_path(locale: :fr)

    assert_select "[style]", 0
    css_select("script").each { |script| assert script["src"].present? || script["nonce"].present?, script.to_html }
    assert_no_match(/data:/, css_select("main, footer").map(&:to_html).join)
    Catalog::CardSeason.pluck(:id).each { |id| assert_no_match(/\b(card[-_]?season|id)[^>]*\b#{id}\b/, response.body) }
  end

  test "the Steam image twice, the hub links with their full name, the external links naming where they lead" do
    get landing_path(locale: :fr)

    assert_select "header form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr/landing']"
    assert_select "main form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr/landing']"
    hub = css_select("main a[href='/fr']")
    assert_equal 2, hub.size
    assert hub.all? { it["aria-label"] == "Embarquer sur le pont, visiter le jeu sans compte" }
    assert_equal 1, hub.count { it["class"].include?("button--primary") }

    project = css_select("main a[href='#{ExternalLinksHelper::SOURCE_CODE_URL}']").sole
    assert_equal "Voir le projet (GitHub, nouvel onglet)", project.text.squish
    assert_equal "_blank", project["target"]
    support = css_select("main a[href='#{ExternalLinksHelper::DONATION_URL}']").sole
    assert_equal "Soutenir (site de dons, nouvel onglet)", support.text.squish

    assert_select "main a[href='#landing-open-source']", "Participer à l'écriture"
    assert_select "h2#landing-open-source[tabindex='-1']"
    assert_select "main a[href='/fr/feed']", "Ouvrir le fil d'activité"
  end

  test "the footer follows the main landmark with the legal page, the donation page and the code" do
    get landing_path(locale: :fr)

    assert_select "body > footer.landing-footer" do
      assert_select "a[href='/fr/legal']", "Mentions légales"
      assert_select "a[href='#{ExternalLinksHelper::DONATION_URL}'][target=_blank]", text: "Soutenir (site de dons, nouvel onglet)"
      assert_select "a[href='#{ExternalLinksHelper::SOURCE_CODE_URL}'][target=_blank]", text: "Code source (GitHub, nouvel onglet)"
    end
    assert_select "main footer", 0
    assert_select "nav.tab-bar", 0
  end

  test "an older browser still reads the landing" do
    get landing_path(locale: :en), headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:60.0) Gecko/20100101 Firefox/60.0" }

    assert_response :success
  end
end
