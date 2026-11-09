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

  test "with no season published Me still links to the achievements and says there is no season" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(@player)

    get me_path(locale: :en)

    assert_response :success
    assert_select ".profile__no-season"
    assert_select "a.me-achievements__all[href='/en/achievements']"
  end

  test "a visitor is sent to the landing in its locale, without an alert" do
    get me_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]
  end

  test "Me is the player's own profile, a customize panel opening the title and the card back, the showcase, then how it works and the settings" do
    choose(:portal_one)
    sign_in(@player)

    written = written_statements { get me_path(locale: :en) }

    assert_response :success
    assert_empty written
    assert_select "title", /\AMe/
    assert_select "main .me[data-controller=me][data-me-back-value=standard][data-action='back-picker:equipped->me#wear'] section.profile"
    assert_select "main h1#profile-heading", "Gabe the Brave"
    assert_select "header.profile-band + section.me-customize h2#me-customize-heading", "Customize"
    assert_select ".me-customize a.me-opener[href='#me-title-sheet'][aria-haspopup=dialog][aria-controls=me-title-sheet][data-bottom-sheet-opens=me-title-sheet]" do
      assert_select ".me-opener__kicker", "Title"
      assert_select ".me-opener__value", "Choose a title"
      assert_select ".me-opener__cue", "Change"
    end
    assert_select ".me-customize a.me-back-opener[href='#me-back-sheet'][data-bottom-sheet-opens=me-back-sheet]" do
      assert_select "[data-me-target=preview] .me-opener__value", "Standard"
      assert_select "[data-me-target=preview] img.back-picker__image[alt='']"
      assert_select ".me-opener__kicker", "Card back · only you"
      assert_select ".me-opener__cue", "Change"
    end
    assert_select ".profile-band .button, .profile-band .me-opener", false
    assert_select ".me-customize + section#showcase h2#profile-showcase-heading", "Showcase"
    assert_select ".me-showcase-opener, #me-showcase-sheet", false
    assert_select "#profile-achievements-heading + a.me-achievements__all[href='/en/achievements'] #plus-achievements-badge.stream-slot"
    assert_select "main a[href='/en/how-it-works'], main a[href='/en/settings']", false
    assert_select "dialog#me-title-sheet:not([open]).bottom-sheet", 1
    assert_select "dialog#me-back-sheet:not([open]).bottom-sheet .back-picker", 1
    assert_select "#me-title-sheet-title", "Profile title"
    assert_select "#me-back-sheet-title", "Card back"
    assert_select "#me-back-sheet .me-sheet__intro", "Only you see it, on your face-down cards when you open a capsule."
    assert_select "[style]", false
  end

  test "the settings are one tap away in the header menu, and no link leads to a former Me screen" do
    sign_in(@player)

    get me_path(locale: :en)

    assert_select "#player-menu a[href='/en/settings']", 1
    assert_select "main a[href='/en/personalization']", false
    assert_select "main a[href^='https://buymeacoffee.com']", false
  end

  test "no tab leads to the profile any more, and its phone header is the top-level one" do
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select "a.tab-bar__tab[href='/fr/me']", false
    assert_select "a.tab-bar__tab[aria-current]", false
    assert_select ".top-bar a.top-bar__phone-back", false
    assert_select ".top-bar__start > p.top-bar__brand.top-bar__phone-brand"
  end

  test "each unlocked back has a template of its look for the preview, the locked ones none" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in(@player)

    get me_path(locale: :en)

    assert_equal %w[set-theme-rpg standard], css_select("template[data-me-target=back]").map { it["data-key"] }.sort
    rpg = css_select("template[data-me-target=back][data-key='set-theme-rpg']").sole
    assert_equal "RPG", rpg.at_css(".me-opener__value").text
  end

  test "the title sheet offers no title, then the earned titles grouped by rank, the worn one current, each a form" do
    earn_valve_titles
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    sign_in(@player)

    get me_path(locale: :fr)

    assert_select ".profile-band .profile-band__title", "Adepte · Valve"
    assert_select ".me-customize a[href='#me-title-sheet'] .me-opener__value.profile-title", "Adepte · Valve"
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
    assert_select "a[href='#me-title-sheet'][autofocus] .me-opener__value", "Adept · Valve"
    assert_select "[autofocus]", 1
  end

  test "the showcase offers a cross on each card, says how to add one, and no showcase sheet" do
    choose(:portal_one, :common_card_one)
    sign_in(@player)

    get me_path(locale: :en)

    assert_equal 2, css_select(".profile-showcase__slot").size
    assert_select ".profile-showcase__slot button.profile-showcase__remove[aria-label^='Remove '][aria-label$=' from the showcase']", 2
    assert_equal [ "/en/cards/portal/seasons/1/showcase", "/en/cards/tin-soldier/seasons/1/showcase" ],
      css_select("dialog .showcase-removal__form").map { it["action"] }
    assert_select ".profile-showcase__info-text", "Up to five cards. Drag them to change their order, and add one from its page with “Add to showcase”."
    assert_select "#me-showcase-sheet", false
    assert_select "[autofocus]", false
  end

  test "a card removed from the showcase comes back to Me with the focus on the next card's cross" do
    choose(:portal_one, :common_card_one, :uncommon_card_one)
    sign_in(@player)

    delete card_showcase_path(locale: :en, slug: "portal", number: 1), headers: { "HTTP_REFERER" => me_path(locale: :en) }

    assert_redirected_to me_path(locale: :en)
    follow_redirect!
    assert_select "#toasts .toast__title", "Removed from showcase"
    assert_equal %w[tin-soldier green-hills], showcase_slugs
    assert_select ".profile-showcase__slot:first-child button.profile-showcase__remove[autofocus][aria-label^=Remove]"
    assert_select "[autofocus]", 1
  end

  test "the last card removed leaves an empty showcase section on Me with the focus on the card list link" do
    choose(:portal_one)
    sign_in(@player)

    delete card_showcase_path(locale: :en, slug: "portal", number: 1), headers: { "HTTP_REFERER" => me_path(locale: :en) }
    follow_redirect!

    assert_select ".profile-showcase", false
    assert_select "section h2#profile-showcase-heading", "Showcase"
    assert_select "section[aria-labelledby=profile-showcase-heading] > .profile-section__aside", /Your best card/
    assert_select "section#showcase a.profile-showcase__browse[href='/en/library/cards'][autofocus]", "See the card list"
    assert_select "[autofocus]", 1
  end

  test "an owner with no chosen card sees the empty showcase section with the card list link, a visitor sees no showcase" do
    sign_in(@player)

    get me_path(locale: :en)

    assert_select "#profile-showcase-heading", "Showcase"
    assert_select "section#showcase a.profile-showcase__browse[href='/en/library/cards']"
    assert_select ".profile-section__aside", /Your best card/

    delete session_path(locale: :en)
    get brother_path(locale: :en, token: @player.token)

    assert_select "#profile-showcase-heading, .profile-showcase", false
  end

  test "Me opened from a card offers a way back to that card; an unknown card offers none" do
    choose(:portal_one)
    sign_in(@player)

    get me_path(locale: :en, card: "portal", edition: 1)
    assert_select ".profile-showcase__head a.profile-showcase__return[href=?]", "/en/cards/portal/seasons/1", "Back to the card"

    get me_path(locale: :fr, card: "portal", edition: 1)
    assert_select "a.profile-showcase__return", "Retour à la carte"

    [ { card: "nowhere", edition: 1 }, { card: "portal", edition: 99 }, { card: "portal", edition: "one" }, { card: "portal" } ].each do |params|
      get me_path(locale: :en, **params)
      assert_response :success
      assert_select "a.profile-showcase__return", false
    end
  end

  test "a visitor of the owner's profile sees the same name, title and showcase order, with no opener, back or sheet" do
    earn_valve_titles
    Game::ChooseProfileTitle.new.call(player: @player, rank: "adept", kind: "studio", key: "valve").value!
    choose(:portal_one, :common_card_one)
    Game::MoveShowcaseCard.new.call(player: @player, card_season_id: catalog_card_seasons(:common_card_one).id, direction: "earlier").value!
    sign_in(@player)
    get me_path(locale: :en)
    mine = [ css_select("h1#profile-heading").text, css_select(".profile-band__title").text, showcase_slugs ]

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
    assert_select "#me-customize-heading", "Personnalisation"
    assert_select "a[href='#me-title-sheet'] .me-opener__kicker", "Titre"
    assert_select "a[href='#me-title-sheet'] .me-opener__value", "Choisir un titre"
    assert_select "a[href='#me-title-sheet'] .me-opener__cue", "Modifier"
    assert_select ".me-back-opener .me-opener__kicker", "Dos de carte · vous seul"
    assert_select ".me-achievements__all", /Tout voir/
    assert_select "#me-title-sheet-title", "Titre de profil"
    assert_select "#me-back-sheet-title", "Dos de carte"
    assert_select "button.profile-showcase__remove[aria-label^=Retirer]", 1
  end

  test "no database id in the openers, the sheets' forms or the templates" do
    choose(:portal_one, :rare_card_one)
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
    sign_in(@player)

    get me_path(locale: :en)

    ids = [ @player.id, catalog_card_seasons(:portal_one).id, catalog_card_seasons(:rare_card_one).id ]
    markup = css_select(".me-opener, dialog.bottom-sheet, dialog.modal, template[data-me-target]").map(&:to_html).join
      .gsub(/name="authenticity_token" value="[^"]*"/, "").gsub(%r{/seasons/\d+|-(xs|s|m)-[^"]*\.png|\b(19|20)\d\d\b|showcase-remove-[a-z0-9-]+}, "")
    ids.each { assert_no_match(/\b#{it}\b/, markup) }
  end
end
