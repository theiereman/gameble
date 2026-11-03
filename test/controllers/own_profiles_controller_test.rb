require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

class OwnProfilesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @player.update_columns(persona_name: "Gabe the Brave")
  end

  def choose(*fixtures)
    fixtures.map { catalog_card_seasons(it).id }.each do |id|
      Game::Holding.create!(player_id: @player.id, card_season_id: id, quantity: 1)
      Game::AddToShowcase.new.call(player: @player, card_season_id: id).value!
    end
  end

  def earn_valve_titles
    season, cards = published_cards(5)
    set_id = insert_set(cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)
    Game::SetTier.insert_all!(%w[novice adept].map { |tier| { player_id: @player.id, set_id:, tier:, reached_by: "trade", reached_at: Time.current } })
  end

  def written_statements(&request)
    statements = []
    record = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    ActiveSupport::Notifications.subscribed(record, "sql.active_record", &request)
    statements
  end

  def showcase_slugs = css_select(".profile-showcase__slot > a.card-link").map { it["href"][%r{/cards/([^/]+)/}, 1] }

  test "a visitor is sent to the landing in its locale, without an alert" do
    get me_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]
  end

  test "Me is the player's own profile, with an opener for the title, the card back and the showcase, then how it works and the settings" do
    choose(:portal_one)
    sign_in(@player)

    written = written_statements { get me_path(locale: :en) }

    assert_response :success
    assert_empty written
    assert_select "title", /\AMe/
    assert_select "main .me[data-controller=me][data-me-back-value=standard][data-action='back-picker:equipped->me#wear'] section.profile"
    assert_select "main h1#profile-heading", "Gabe the Brave"
    assert_select ".profile-band a.me-title-opener[href='#me-title-sheet'][aria-haspopup=dialog][aria-controls=me-title-sheet][data-bottom-sheet-opens=me-title-sheet]" do
      assert_select ".me-opener__value", "Choose a title"
      assert_select ".me-opener__cue", "Change"
    end
    assert_select ".profile-band a.me-back-opener[href='#me-back-sheet'][data-bottom-sheet-opens=me-back-sheet]" do
      assert_select "[data-me-target=preview] .me-back-opener__name", "Standard"
      assert_select "[data-me-target=preview] img.back-picker__image[alt='']"
      assert_select ".me-back-opener__scope", "Card back · only you"
      assert_select ".me-opener__cue", "Change"
    end
    assert_select ".profile-band .button", false
    assert_select ".profile-showcase__head a.me-showcase-opener[href='#me-showcase-sheet']", "Edit"
    assert_select "#profile-achievements-heading ~ a.me-achievements__all[href='/en/achievements'] #plus-achievements-badge.stream-slot"
    assert_equal [ "/en/how-it-works", "/en/settings" ], css_select("main nav.me-links .plus__list a.menu-item").map { it["href"] }
    assert_select "dialog#me-title-sheet:not([open]).bottom-sheet", 1
    assert_select "dialog#me-back-sheet:not([open]).bottom-sheet .back-picker", 1
    assert_select "dialog#me-showcase-sheet:not([open]).bottom-sheet", 1
    assert_select "#me-title-sheet-title", "Profile title"
    assert_select "#me-back-sheet-title", "Card back"
    assert_select "#me-showcase-sheet-title", "Showcase"
    assert_select "#me-back-sheet .me-sheet__intro", "Only you see it, on your face-down cards when you open a capsule."
    assert_select "[style]", false
  end

  test "exactly one link in the page leads to the settings, and none to a former Me screen" do
    sign_in(@player)

    get me_path(locale: :en)

    assert_equal 1, css_select("main a[href='/en/settings']").size
    assert_select "main a[href='/en/personalization']", false
    assert_select "main a[href^='https://buymeacoffee.com']", false
  end

  test "the Me tab is current and the phone header is the top-level one" do
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select "a.tab-bar__tab[href='/fr/me'][aria-current=page]", /Moi/
    assert_select ".top-bar a.top-bar__phone-back", false
    assert_select ".top-bar__start > p.top-bar__brand.top-bar__phone-brand"
  end

  test "each unlocked back has a template of its look for the preview, the locked ones none" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in(@player)

    get me_path(locale: :en)

    assert_equal %w[set-theme-rpg standard], css_select("template[data-me-target=back]").map { it["data-key"] }.sort
    rpg = css_select("template[data-me-target=back][data-key='set-theme-rpg']").sole
    assert_equal "RPG", rpg.at_css(".me-back-opener__name").text
  end

  test "the title sheet offers no title, then the earned titles grouped by rank, the worn one current, each a form" do
    earn_valve_titles
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select ".profile-band .me-title-opener .me-opener__value.profile-title", "Adepte · Valve"
    assert_select "#me-title-sheet .me-sheet__intro", "Votre titre s'affiche sur votre profil, dans le fil d'activité et dans vos échanges."
    assert_equal [ "Adepte", "Novice" ], css_select("#me-title-sheet .me-sheet__heading").map(&:text)
    assert_equal [ "Aucun titre", "Adepte · Valve", "Novice · Valve" ], css_select("#me-title-sheet button.filter-chip").map { it.text.strip }
    assert_equal [ "", "novice:studio:valve" ], css_select("#me-title-sheet form input[name=title]").map { it["value"] }
    assert_select "#me-title-sheet form[action='/fr/personalization/title'] input[name=_method][value=patch]", 2
    assert_select "#me-title-sheet button[aria-current=true]", 1
    assert_select "#me-title-sheet button[type=button][aria-current=true][data-action='bottom-sheet#close']", "Adepte · Valve"
    assert_select "#me-title-sheet form button[aria-current]", false
    assert_select "#me-title-sheet .me-sheet__note", false
  end

  test "with no title earned the title sheet offers only no title, current, and says how to earn one" do
    sign_in(@player)

    get me_path(locale: :en)

    assert_select "#me-title-sheet button.filter-chip", 1
    assert_select "#me-title-sheet button.filter-chip[aria-current=true]", "No title"
    assert_select "#me-title-sheet .me-sheet__note", /Reach a tier of a set/
  end

  test "a chosen title comes back on Me with its toast and the focus on the title" do
    earn_valve_titles
    sign_in(@player)

    patch personalization_title_path(locale: :en), params: { title: "adept:studio:valve" }

    assert_redirected_to me_path(locale: :en)
    follow_redirect!
    assert_select ".toast", /Title equipped/
    assert_select ".me-title-opener[autofocus] .me-opener__value", "Adept · Valve"
    assert_select "[autofocus]", 1
  end

  test "the showcase sheet lists the chosen cards, each with its remove button, says how to add one and links to the card list" do
    choose(:portal_one, :common_card_one)
    sign_in(@player)

    get me_path(locale: :en)

    titles = css_select(".profile-showcase__slot").map { it.at_css(".card-link")["aria-label"] }
    assert_equal 2, titles.size
    assert_select "#me-showcase-sheet .me-sheet__intro", "Up to five cards, at the top of your public profile."
    assert_select "#me-showcase-sheet .me-showcase-row", 2
    assert_select "#me-showcase-sheet .me-showcase-row .card.card--s", 2
    assert_equal %w[delete delete], css_select("#me-showcase-sheet .me-showcase-row form input[name=_method]").map { it["value"] }
    assert_equal [ "/en/cards/portal/seasons/1/showcase", "/en/cards/tin-soldier/seasons/1/showcase" ],
      css_select("#me-showcase-sheet .me-showcase-row form").map { it["action"] }
    assert_select "#me-showcase-sheet .me-showcase-row button[aria-label^='Remove '][aria-label$=' from the showcase']", 2
    assert_select "#me-showcase-sheet .me-sheet__note", "Add a card from its page, with “Add to showcase”. Drag the cards on your profile to change their order."
    assert_select "#me-showcase-sheet a.me-sheet__link[href='/en/library/cards']", "See the card list"
    assert_select "#me-showcase-sheet [autofocus]", false
  end

  test "a card removed from the showcase sheet sends the sheet open with the focus on the next card's remove button" do
    choose(:portal_one, :common_card_one, :uncommon_card_one)
    sign_in(@player)

    delete card_showcase_path(locale: :en, slug: "portal", number: 1), headers: { "HTTP_REFERER" => me_path(locale: :en) }

    assert_redirected_to me_path(locale: :en)
    follow_redirect!
    assert_select "#toasts .toast__title", "Removed from showcase"
    assert_equal %w[tin-soldier green-hills], showcase_slugs
    assert_select "dialog#me-showcase-sheet[open]"
    assert_select "dialog#me-showcase-sheet .me-showcase-row:first-child button[autofocus][aria-label^=Remove]"
    assert_select "[autofocus]", 1
  end

  test "the last card removed leaves an empty showcase section on Me and the sheet open on the card list link" do
    choose(:portal_one)
    sign_in(@player)

    delete card_showcase_path(locale: :en, slug: "portal", number: 1), headers: { "HTTP_REFERER" => me_path(locale: :en) }
    follow_redirect!

    assert_select ".profile-showcase", false
    assert_select "section h2#profile-showcase-heading", "Showcase"
    assert_select "section[aria-labelledby=profile-showcase-heading] > .profile-section__aside", /Your best card/
    assert_select "dialog#me-showcase-sheet[open] .me-showcase-row", false
    assert_select "dialog#me-showcase-sheet[open] a.me-sheet__link[autofocus]"
    assert_select "[autofocus]", 1
  end

  test "an owner with no chosen card sees the empty showcase section with its opener, a visitor sees no showcase" do
    sign_in(@player)

    get me_path(locale: :en)

    assert_select "#profile-showcase-heading", "Showcase"
    assert_select ".profile-showcase__head a.me-showcase-opener"
    assert_select ".profile-section__aside", /Your best card/

    delete session_path(locale: :en)
    get brother_path(locale: :en, token: @player.token)

    assert_select "#profile-showcase-heading, .profile-showcase", false
  end

  test "a visitor of the owner's profile sees the same name, title and showcase order, with no opener, back or sheet" do
    earn_valve_titles
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    choose(:portal_one, :common_card_one)
    Game::MoveShowcaseCard.new.call(player: @player, card_season_id: catalog_card_seasons(:common_card_one).id, direction: "earlier").value!
    sign_in(@player)
    get me_path(locale: :en)
    mine = [ css_select("h1#profile-heading").text, css_select(".me-title-opener .profile-title").text, showcase_slugs ]

    sign_in(accounts_players(:moderator))
    get brother_path(locale: :en, token: @player.token)

    assert_equal mine, [ css_select("h1#profile-heading").text, css_select(".profile-band__title").text, showcase_slugs ]
    assert_equal %w[tin-soldier portal], showcase_slugs
    assert_select ".me-opener, .me-back-opener, dialog.bottom-sheet, .back-picker, template[data-me-target]", false
    assert_select "[data-controller~=me]", false
  end

  test "a card opened from Me goes back to Me, labelled Me; without a session the context is ignored" do
    choose(:portal_one)
    sign_in(@player)

    get me_path(locale: :en)
    href = css_select(".profile-showcase__slot > a.card-link").sole["href"]
    assert_equal card_season_path(locale: :en, slug: "portal", number: 1, from: "me"), href

    get href
    assert_response :success
    assert_select ".top-bar__phone-back[href=?]", me_path(locale: :en), /Me/

    delete session_path(locale: :en)
    get card_season_path(locale: :en, slug: "portal", number: 1, from: "me")
    assert_select ".top-bar__phone-back[href=?]", me_path(locale: :en), false
  end

  test "the old Personalization address redirects for good to Me in its locale" do
    get personalization_path(locale: :fr)

    assert_redirected_to "/fr/me"
    assert_response :moved_permanently
  end

  test "in French: the openers, the sheets and the links" do
    choose(:portal_one)
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select "title", /\AMoi/
    assert_select ".me-title-opener .me-opener__value", "Choisir un titre"
    assert_select ".me-title-opener .me-opener__cue", "Modifier"
    assert_select ".me-back-opener .me-back-opener__scope", "Dos de carte · vous seul"
    assert_select ".me-showcase-opener", "Modifier"
    assert_select ".me-achievements__all .menu-item__label", "Voir tous les succès"
    assert_equal [ "Comment ça marche", "Paramètres" ], css_select(".me-links .menu-item__label").map(&:text)
    assert_select "nav.me-links[aria-label=?]", "Aide et paramètres"
    assert_select "#me-title-sheet-title", "Titre de profil"
    assert_select "#me-back-sheet-title", "Dos de carte"
    assert_select "#me-showcase-sheet-title", "Vitrine"
    assert_select "#me-showcase-sheet a.me-sheet__link", "Voir la liste des cartes"
    assert_select "#me-showcase-sheet button[aria-label^=Retirer]", 1
  end

  test "no database id in the openers, the sheets' forms or the templates" do
    choose(:portal_one, :rare_card_one)
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in(@player)

    get me_path(locale: :en)

    ids = [ @player.id, catalog_card_seasons(:portal_one).id, catalog_card_seasons(:rare_card_one).id ]
    markup = css_select(".me-opener, .me-back-opener, dialog.bottom-sheet, template[data-me-target]").map(&:to_html).join
      .gsub(/name="authenticity_token" value="[^"]*"/, "").gsub(%r{/seasons/\d+|-(xs|s|m)-[^"]*\.png|\b(19|20)\d\d\b}, "")
    ids.each { assert_no_match(/\b#{it}\b/, markup) }
  end
end
