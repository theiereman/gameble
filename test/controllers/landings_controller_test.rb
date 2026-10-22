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
    assert_select "section.landing-concept > a.button.button--link.landing-concept__all-cards[href='/fr/library/cards']", "Voir toutes les cartes"
  end

  test "a visitor reads the landing in English" do
    get landing_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_headings(:en)
    assert_equal [ "Tin Soldier", "Green Hills", "Blue Depths", "Portal", "Golden Crown" ], concept_faces
    assert_select ".landing-rarities li .landing-rarity__odds", text: "4.3% per card"
    assert_select "section.landing-concept > a.button.button--link.landing-concept__all-cards[href='/en/library/cards']", "See every card"
  end

  test "the Brotherhood's panel tells its story in the visitor's language" do
    %i[fr en].each do |locale|
      get landing_path(locale:)

      story = %w[recovery archive thanks].map { I18n.t("landings.show.brotherhood.lore.story.#{it}", locale:) }
      assert_equal story, css_select(".landing-lore__story p").map { it.text.squish }
    end
  end

  test "the Découvrez tile promises no name to anyone" do
    %i[fr en].each do |locale|
      get landing_path(locale:)

      assert_select ".landing-tile", text: /#{Regexp.escape(I18n.t("landings.show.brotherhood.tiles.discover.text", locale:))}/
      refute_match(/engrave|grave son nom/, response.body)
    end
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

  test "the hero's lamp field is hidden from assistive technology: six slots over the samples, one a back, a veil, a reticle and the readout" do
    get landing_path(locale: :fr)

    assert_response :success
    assert_select ".landing-hero [data-controller=lamp-field][aria-hidden=true]", 1
    assert_select "[data-controller=lamp-field] a, [data-controller=lamp-field] button, [data-controller=lamp-field] [tabindex]", 0
    assert_select "[data-lamp-field-target=card]", 6
    assert_select "[data-lamp-field-target=card] .card", 5
    assert_select "[data-lamp-field-target=card] img.landing-lamp__back[alt='']", 1
    assert_select "[data-lamp-field-target=veil]", 1
    assert_select "[data-lamp-field-target=reticle]", 1
    assert_select ".landing-lamp__readout", text: /Jeux retrouvés\s+0 \/ 6/
    assert_select ".landing-lamp__tag", text: "Trouvé", count: 6
    assert_select ".landing-lamp__mode", text: "· Balayage auto"
    assert_select ".landing-lamp__mode", text: "· Balayage manuel"
    assert_select ".landing-lamp__mode", text: "· Balayage fixe"
  end

  test "the hero's lamp field shows only card backs without a published season" do
    Catalog::Season.update_all(status: "draft", published_at: nil)

    get landing_path(locale: :en)

    assert_select "[data-lamp-field-target=card] .card", 0
    assert_select "[data-lamp-field-target=card] img.landing-lamp__back", 6
    assert_select ".landing-lamp__readout", text: /Games found\s+0 \/ 6/
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

  test "the Steam image twice, the two boardings signing in with their full name, the external links naming where they lead" do
    get landing_path(locale: :fr)

    assert_select "header form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr/landing']"
    assert_select "main form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr/landing']"
    boardings = css_select("main form.button-form[action='/auth/steam'][method=post][data-turbo=false]")
    assert_equal 2, boardings.size
    assert(boardings.all? { it.at_css("input[name=origin]")["value"] == "/fr/landing" })
    buttons = boardings.map { it.at_css("button[type=submit]") }
    assert(buttons.all? { it.text.squish == "Embarquer sur le pont" && it["aria-label"] == "Embarquer sur le pont, se connecter avec Steam" })
    assert_equal [ "landing-hero__embark", "landing-boarding__embark" ], buttons.map { it["class"].split.last }
    assert_equal 1, buttons.count { it["class"].include?("button--primary") }
    assert_select "main a[href='/fr']", false
    [ ".landing-hero__action", ".landing-boarding__actions" ].each do |actions|
      assert_select "#{actions} p.sign-in-acceptance",
        "En vous connectant, vous acceptez les conditions d'utilisation et prenez connaissance de la politique de confidentialité." do
        assert_select "a[href=?]", "/fr/legal#legal-terms", "conditions d'utilisation"
        assert_select "a[href=?]", "/fr/legal#legal-privacy", "politique de confidentialité"
      end
    end

    project = css_select("main a[href='#{ExternalLinksHelper::SOURCE_CODE_URL}']").sole
    assert_equal "Voir le projet (GitHub, nouvel onglet)", project.text.squish
    assert_equal "_blank", project["target"]
    support = css_select("main a[href='#{ExternalLinksHelper::DONATION_URL}']").sole
    assert_equal "Soutenir (site de dons, nouvel onglet)", support.text.squish

    assert_select "main a[href='#landing-open-source']", "Participer à l'écriture"
    assert_select "h2#landing-open-source[tabindex='-1']"
    assert_select "main a.landing-live__open[href='/fr/feed']", "Ouvrir le fil d'activité"
    assert_select "main button.landing-live__open", false
  end

  test "the footer follows the main landmark with how it works, the legal page, the donation page and the code" do
    get landing_path(locale: :fr)

    assert_select "body > footer.landing-footer" do
      assert_select "a[href='/fr/how-it-works']", "Comment ça marche"
      assert_select "a[href='/fr/legal']", "Mentions légales"
      assert_select "a[href='#{ExternalLinksHelper::DONATION_URL}'][target=_blank]", text: "Soutenir (site de dons, nouvel onglet)"
      assert_select "a[href='#{ExternalLinksHelper::SOURCE_CODE_URL}'][target=_blank]", text: "Code source (GitHub, nouvel onglet)"
    end
    assert_select "main footer", 0
    assert_select "nav.tab-bar", 0
  end

  test "a visitor follows the landing footer to how it works" do
    get landing_path(locale: :en)
    assert_select "footer.landing-footer a[href='/en/how-it-works']", "How it works"

    get how_it_works_path(locale: :en)

    assert_response :success
  end

  def seed_roadmap
    epics = %w[alpha beta gamma delta].map { Catalog::InitiativeEpics::Epic.new(slug: it, title: it.titleize) }
    milestones = Catalog::CreateRoadmapMilestones.new.call(epics:).value!
    shown = milestones.first(3)
    shown.zip(%w[done in_progress to_come]).each do |milestone, status|
      Catalog::UpdateRoadmapMilestone.new.call(milestone:, wording_fr: "Étape #{milestone.epic_slug}", wording_en: "Step #{milestone.epic_slug}", status:, shown: true).value!
    end
    [ [ "a", "done", true ], [ "b", "in_progress", true ], [ "c", "to_come", true ], [ "hidden", "done", false ] ].each do |name, status, visible|
      Catalog::CreateRoadmapStory.new.call(milestone: shown.first, wording_fr: "Récit #{name}", wording_en: "Story #{name}", status:, shown: visible).value!
    end
    shown
  end

  test "module 06 shows the shown milestones and their first two shown stories with their status in text" do
    seed_roadmap

    get landing_path(locale: :fr)

    items = css_select("ol.landing-roadmap__line > li")
    assert_equal [ "Fait", "En cours", "À venir" ], items.map { it.at_css(".landing-roadmap__status").text }
    assert_equal [ "Étape alpha", "Étape beta", "Étape gamma" ], items.map { it.at_css(".landing-roadmap__name").text }
    assert_equal [ "Récit a, Fait", "Récit b, En cours" ], items.first.css(".landing-roadmap__story").map { it.text.squish }
    assert_select ".landing-roadmap__stories", 1
    assert_select "ol.landing-roadmap__line[aria-label=?][data-controller=overflow-focus]", I18n.t("landings.show.roadmap.line_label", locale: :fr)
    assert_select ".landing-legend__item", 3
  end

  test "module 06 reads in English" do
    seed_roadmap

    get landing_path(locale: :en)

    assert_select ".landing-roadmap__milestone--done .landing-roadmap__name", "Step alpha"
    assert_select ".landing-roadmap__story", text: /Story a, Done/
    assert_select ".landing-roadmap__status", text: "To come"
  end

  test "module 06 keeps the legend and no line while no milestone is shown" do
    get landing_path(locale: :fr)

    assert_select "ol.landing-roadmap__line", 0
    assert_select ".landing-legend__item", 3
  end

  test "an older browser still reads the landing" do
    get landing_path(locale: :en), headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:60.0) Gecko/20100101 Firefox/60.0" }

    assert_response :success
  end
end
