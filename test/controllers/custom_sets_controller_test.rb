require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/custom_sets"
require_relative "../support/steam_sign_in"

# A player's own sets through HTTP: the album, its author's only, with the
# editor and the delete dialog; the editor's games frame, its search, chips
# and pages; saving a new or an edited set and its inline refusals; deleting.
class CustomSetsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GameSets
  include Holdings
  include CustomSets
  include SteamSignIn

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @player = accounts_players(:player)
  end

  def slug(name) = catalog_cards(name).slug

  def slugs_of(*names) = names.map { slug(it) }

  def writes = Game::CustomSet.count + Game::CustomSetGame.count + Rails.configuration.event_store.read.count

  def second_season_of(names)
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    names.each_with_index.to_h do |name, index|
      [ name, Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(name).id, season_id: season.id, prestige_score: 0.5, rating: 80.0,
        rarity: "common", number: index + 1 } ], returning: :id).rows.flatten.sole ]
    end
  end

  def slots
    css_select(".set-album__grid > li a.card-link").map do |link|
      [ link.at_css(".card").classes.include?("card--not-owned") ? :missing : :owned, link["href"] ]
    end
  end

  def get_games(locale: :en, frame: "custom-set-games", **params)
    get custom_set_games_path(locale:, **params), headers: { "Turbo-Frame" => frame }
  end

  def shown_games = css_select(".custom-set-game").map { it["data-key"] }

  def game_labels = css_select(".custom-set-game__toggle").map { it["aria-label"] }

  def board_slugs(count)
    _season, card_season_ids = published_cards(count)
    Catalog::Card.where(id: Catalog::CardSeason.where(id: card_season_ids).select(:card_id)).order(:id).pluck(:slug)
  end

  def assert_refusal(message)
    assert_response :unprocessable_content
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=update][target=custom-set-editor-refusal] template", message
  end

  test "the author's album: its name, owned over total, a bar to complete without ticks, a game held in an earlier season face up, the others not owned" do
    second_season_of(%i[portal common_card rare_card])
    custom_set = create_custom_set(@player, card_ids: %i[portal common_card rare_card].map { catalog_cards(it).id })
    hold(@player, catalog_card_seasons(:common_card_one).id)
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)

    assert_response :success
    assert_select "title", "Mes favoris · Collection · Gameble"
    assert_select "h1#set-album-heading", "Mes favoris"
    assert_equal "1/3", css_select(".set-album__count").sole.text.squish
    assert_select "progress.set-album__bar[value='1'][max='3'][aria-valuetext='1 card out of 3']"
    assert_select ".set-album__ticks, .set-album__stamp, .set-album__header--tiered", false
    assert_equal [ [ :missing, "/en/cards/#{slug(:portal)}/seasons/2" ], [ :owned, "/en/cards/#{slug(:common_card)}/seasons/1" ],
      [ :missing, "/en/cards/#{slug(:rare_card)}/seasons/2" ] ], slots
    assert_select ".set-album__title .set-album__actions" do
      assert_select "button.button[type=button][aria-haspopup=dialog][data-dialog-opener-dialog-value=custom-set-editor]", "Edit"
      assert_select "button.button[type=button][aria-haspopup=dialog][data-dialog-opener-dialog-value=delete-custom-set]", "Delete"
    end
    assert_select "[data-turbo-confirm]", false
    assert_select "header.top-bar[data-screen-label=Set]"
    assert_select "[style]", false
    assert_equal [ "Portal", "Blue Depths" ], css_select(".set-album__grid > li .card--not-owned .card__title").map { it.text.squish }
  end

  test "a game gained since the collection was last seen carries the New tag on the custom album" do
    custom_set = create_custom_set(@player, card_ids: %i[portal common_card rare_card].map { catalog_cards(it).id })
    Game::PlayerState.find_by!(player_id: @player.id).update_columns(collection_seen_up_to: 1.hour.ago)
    hold(@player, catalog_card_seasons(:common_card_one).id, 1, gained_at: 1.minute.ago)
    hold(@player, catalog_card_seasons(:portal_one).id, 1, gained_at: 2.hours.ago)
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)

    assert_equal [ false, true, false ], css_select(".set-album__grid > li").map { it.at_css(".collection-slot__new").present? }
  end

  test "a set whose games are all held is complete, with no tier and no reward" do
    custom_set = create_custom_set(@player, card_ids: %i[portal common_card rare_card].map { catalog_cards(it).id })
    %i[portal_one common_card_one rare_card_one].each { hold(@player, catalog_card_seasons(it).id) }
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)

    assert_equal "3/3", css_select(".set-album__count").sole.text.squish
    assert_select ".set-album__header--complete"
    assert_select ".set-album__ticks, .set-album__header--tiered", false
  end

  test "no database id of the set or its games is in the album, the list or the editor's games" do
    %w[game_custom_sets_id_seq game_custom_set_games_id_seq].each do |sequence|
      ActiveRecord::Base.connection.execute("SELECT setval('#{sequence}', #{7_000_000_000 + SecureRandom.random_number(1_000_000)})")
    end
    custom_set = create_custom_set(@player)
    ids = [ custom_set.id, *Game::CustomSetGame.where(custom_set_id: custom_set.id).pluck(:id, :card_id).flatten ].map(&:to_s)
    sign_in(@player)

    [ custom_set_path(locale: :en, token: custom_set.token), library_path(locale: :en) ].each do |path|
      get path
      assert_response :success
      ids.each { assert_no_match(/\b#{it}\b/, response.body, path) }
    end

    get_games(state: "picked", games: Catalog::Card.where(id: fixture_card_ids).pluck(:slug))
    assert_equal 5, shown_games.size
    (ids + Catalog::CardSeason.where(card_id: fixture_card_ids).ids.map(&:to_s)).each { assert_no_match(/\b#{it}\b/, response.body, "games") }
  end

  test "another player's set is refused without its name; a visitor is sent to the landing; an unknown token is not found" do
    custom_set = create_custom_set(accounts_players(:moderator), name: "Secret garden")
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)
    assert_response :forbidden
    assert_no_match(/Secret garden/, response.body)

    assert_no_difference -> { writes } do
      patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "Mine", games: slugs_of(:portal, :rare_card, :common_card) }, headers: STREAM
    end
    assert_response :forbidden

    get custom_set_path(locale: :en, token: "1" * 24)
    assert_response :not_found

    reset!
    get custom_set_path(locale: :en, token: custom_set.token)
    assert_redirected_to home_path(locale: :en)
    get custom_set_path(locale: :en, token: "1" * 24)
    assert_redirected_to home_path(locale: :en)
  end

  test "no published season, no album" do
    custom_set = create_custom_set(@player)
    Catalog::Season.update_all(status: "draft", published_at: nil)
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)

    assert_response :not_found
  end

  test "the games frame lists every published game, one face each, owned or not, and writes nothing" do
    second_season_of(%i[portal])
    hold(@player, catalog_card_seasons(:common_card_one).id)
    hold(@player, catalog_card_seasons(:portal_one).id)
    sign_in(@player)

    assert_no_difference -> { writes } do
      get_games
    end

    assert_response :success
    assert_select "turbo-frame#custom-set-games" do
      assert_select "ul.custom-set-editor__grid[aria-labelledby=custom-set-editor-title][data-custom-set-editor-target=grid]"
      assert_equal slugs_of(:portal, :common_card, :uncommon_card, :rare_card, :legendary_card), shown_games
      assert_equal [ "Portal, owned", "Tin Soldier, owned", "Green Hills, not owned", "Blue Depths, not owned", "Golden Crown, not owned" ], game_labels
      assert_select ".custom-set-game__toggle[type=button][tabindex='-1'][aria-pressed=false][data-action='custom-set-editor#toggle']", 5
      assert_select ".custom-set-game .card.card--s", 5
      assert_select ".custom-set-game[data-key='#{slug(:portal)}'] .card:not(.card--not-owned) .card__number", "#1"
      assert_select ".custom-set-game[data-key='#{slug(:uncommon_card)}'] .card.card--not-owned .card__lock"
      assert_select ".custom-set-editor__more", false
    end
    assert_select "[style]", false
  end

  test "the chips narrow the frame to the owned games, the missing ones, or the picked ones in pick order; the search to a title or a studio" do
    hold(@player, catalog_card_seasons(:rare_card_one).id)
    sign_in(@player)

    get_games(state: "owned")
    assert_equal slugs_of(:rare_card), shown_games
    get_games(state: "missing", q: "o")
    assert_equal slugs_of(:common_card, :portal, :legendary_card), shown_games
    get_games(state: "picked", games: [ slug(:portal), "unknown", slug(:common_card), slug(:portal) ])
    assert_equal slugs_of(:portal, :common_card), shown_games
    get_games(state: "picked", q: "tin", games: slugs_of(:portal, :common_card))
    assert_equal slugs_of(:common_card), shown_games
    get_games(state: "picked")
    assert_empty shown_games
    get_games(q: "valve")
    assert_equal slugs_of(:portal), shown_games
    get_games(locale: :fr, q: "collines")
    assert_equal slugs_of(:uncommon_card), shown_games
    get_games(state: "everything")
    assert_equal 5, shown_games.size
  end

  test "a search with no game names it; an empty chip says so" do
    sign_in(@player)

    get_games(locale: :fr, q: "zzzz")
    assert_select "ul.custom-set-editor__grid", false
    assert_select ".custom-set-editor__note", "Aucun jeu trouvé pour «\u202Fzzzz\u202F»."

    get_games(state: "owned")
    assert_select ".custom-set-editor__note", "No game to show."
  end

  test "the frame shows 48 games, then the next page loads into its own frame" do
    slugs = board_slugs(50)
    sign_in(@player)

    get_games(q: "seed")
    assert_equal slugs.first(48), shown_games
    assert_select "turbo-frame#custom-set-games > turbo-frame#custom-set-games-page-2.custom-set-editor__more a.button[href=?]",
      "/en/library/custom-sets/games?page=2&q=seed", text: "Load more"

    get_games(q: "seed", page: 2, frame: "custom-set-games-page-2")
    assert_select "turbo-frame#custom-set-games-page-2 > ul.custom-set-editor__grid[data-custom-set-editor-target=page]"
    assert_equal slugs.last(2), shown_games
    assert_select ".custom-set-editor__more", false

    get_games(state: "picked", games: slugs)
    assert_select "a.button[href=?]", "/en/library/custom-sets/games?#{{ games: slugs, page: 2, state: "picked" }.to_query}"
    get_games(state: "picked", games: slugs, page: 2, frame: "custom-set-games-page-2")
    assert_equal slugs.last(2), shown_games

    get_games(page: 99, frame: "custom-set-games-page-99")
    assert_empty shown_games
    assert_select ".custom-set-editor__note", false
  end

  test "the games frame outside a frame goes to the collection; a visitor is sent to the landing" do
    sign_in(@player)
    get custom_set_games_path(locale: :en)
    assert_redirected_to library_path(locale: :en)

    reset!
    get_games
    assert_redirected_to home_path(locale: :en)
  end

  test "saving a new set lands on the collection, where MES SETS lists it" do
    sign_in(@player)

    assert_difference -> { Game::CustomSet.count }, 1 do
      post custom_sets_path(locale: :en), params: { name: "Mes favoris", games: slugs_of(:portal, :rare_card, :common_card) }, headers: STREAM
    end

    custom_set = Game::CustomSet.last
    assert_response :see_other
    assert_redirected_to library_path(locale: :en)
    assert_equal %i[portal rare_card common_card].map { catalog_cards(it).id }, Game::CustomSetGame.where(custom_set_id: custom_set.id).order(:id).pluck(:card_id)

    get library_path(locale: :en)
    assert_select "section.custom-sets[aria-labelledby=custom-sets-title]" do
      assert_select "h2#custom-sets-title", "My sets"
      assert_select ".custom-sets__note", "Visible to you only · 1 / 10"
      assert_select "ul.set-tiles > li > a.set-tile[href='/en/library/custom-sets/#{custom_set.token}']" do
        assert_select ".set-tile__face--recto .set-tile__name", "Mes favoris"
        assert_select ".set-tile__face--recto .set-tile__kind", "Custom set · 3 games"
        assert_select ".set-tile__face--recto .set-tile__head > .set-tile__count", "0/3"
        assert_select "a > .visually-hidden", "Mes favoris, custom set, 0 cards out of 3"
      end
      assert_select "ul.set-tiles > li:last-child > button.new-set-tile[type=button][aria-haspopup=dialog][data-dialog-opener-dialog-value=custom-set-editor]" do
        assert_select ".new-set-tile__title", "New set"
        assert_select ".new-set-tile__rule", "3 to 50 games · 10 sets at most"
      end
    end
  end

  test "a refusal of a new set updates the editor's refusal line, in English and in French, and writes nothing" do
    create_custom_set(@player, name: "Autre")
    three = slugs_of(:portal, :rare_card, :common_card)
    sign_in(@player)

    assert_no_difference -> { writes } do
      post custom_sets_path(locale: :en), params: { name: "Mes favoris", games: three.first(2) }, headers: STREAM
      assert_refusal "3 GAMES AT LEAST · Add 1 more game to save the set."
      post custom_sets_path(locale: :fr), params: { name: "Mes favoris", games: three.first(1) }, headers: STREAM
      assert_refusal "3 JEUX AU MOINS · Ajoutez encore 2 jeux pour enregistrer le set."
      post custom_sets_path(locale: :en), params: { name: "  ", games: three }, headers: STREAM
      assert_refusal "NAME REQUIRED · Give your set a name."
      post custom_sets_path(locale: :fr), params: { games: three }, headers: STREAM
      assert_refusal "NOM REQUIS · Donnez un nom à votre set."
      post custom_sets_path(locale: :en), params: { name: "AUTRE", games: three }, headers: STREAM
      assert_refusal "NAME TAKEN · Another of your sets has this name."
      post custom_sets_path(locale: :en), params: { name: "x", games: three.first(2) + [ "unknown" ] }, headers: STREAM
      assert_refusal "A chosen game is not in the catalog. Reload the page and try again."
    end
  end

  test "an eleventh set is refused inline; ten sets: no new set button and no editor" do
    10.times { create_custom_set(@player, name: "Set #{it}") }
    sign_in(@player)

    assert_no_difference -> { writes } do
      post custom_sets_path(locale: :fr), params: { name: "Onze", games: slugs_of(:portal, :rare_card, :common_card) }, headers: STREAM
    end
    assert_refusal "10 SETS AU PLUS · Retirez un set pour en créer un autre."

    get library_path(locale: :en)
    assert_select ".custom-sets__note", "Visible to you only · 10 / 10 · remove a set to create another"
    assert_select ".custom-sets a.set-tile", 10
    assert_select ".new-set-tile, #custom-set-editor", false
  end

  test "a refusal answered as HTML returns where the editor was, with its message" do
    custom_set = create_custom_set(@player)
    sign_in(@player)

    post custom_sets_path(locale: :en), params: { name: "x", games: slugs_of(:portal) }
    assert_redirected_to library_path(locale: :en)
    assert_equal "3 GAMES AT LEAST · Add 2 more games to save the set.", flash[:alert]

    patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "", games: slugs_of(:portal, :rare_card, :common_card) }
    assert_redirected_to custom_set_path(locale: :en, token: custom_set.token)
    assert_equal "NAME REQUIRED · Give your set a name.", flash[:alert]
  end

  test "saving an edit replaces the name and the games in pick order and lands on the album" do
    custom_set = create_custom_set(@player, card_ids: %i[portal rare_card common_card].map { catalog_cards(it).id })
    sign_in(@player)

    patch custom_set_path(locale: :en, token: custom_set.token),
      params: { name: "Jeux du soir", games: slugs_of(:common_card, :legendary_card, :portal, :uncommon_card) }, headers: STREAM

    assert_response :see_other
    assert_redirected_to custom_set_path(locale: :en, token: custom_set.token)
    assert_equal "Jeux du soir", custom_set.reload.name
    assert_equal %i[common_card legendary_card portal uncommon_card].map { catalog_cards(it).id },
      Game::CustomSetGame.where(custom_set_id: custom_set.id).order(:id).pluck(:card_id)

    follow_redirect!
    assert_select "h1#set-album-heading", "Jeux du soir"
    assert_equal 4, slots.size
  end

  test "an edit keeps its own name; its refusals update the refusal line and change nothing" do
    create_custom_set(@player, name: "Autre")
    custom_set = create_custom_set(@player)
    sign_in(@player)

    patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "MES FAVORIS", games: slugs_of(:portal, :rare_card, :legendary_card) }, headers: STREAM
    assert_redirected_to custom_set_path(locale: :en, token: custom_set.token)
    many = board_slugs(51)

    assert_no_difference -> { writes } do
      patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "autre", games: slugs_of(:portal, :rare_card) * 2 }, headers: STREAM
      assert_refusal "3 GAMES AT LEAST · Add 1 more game to save the set."
      patch custom_set_path(locale: :fr, token: custom_set.token), params: { name: "autre", games: slugs_of(:portal, :rare_card, :common_card) }, headers: STREAM
      assert_refusal "NOM DÉJÀ PRIS · Un autre de vos sets porte ce nom."
      patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "x", games: many }, headers: STREAM
      assert_refusal "50 GAMES AT MOST · Remove a game to add another."
    end
    assert_equal "MES FAVORIS", custom_set.reload.name
  end

  test "deleting the set returns to the collection with its toast; another player's set is refused" do
    custom_set = create_custom_set(@player)
    theirs = create_custom_set(accounts_players(:moderator))
    sign_in(@player)

    assert_no_difference -> { Game::CustomSet.count } do
      delete custom_set_path(locale: :en, token: theirs.token)
    end
    assert_response :forbidden

    delete custom_set_path(locale: :fr, token: custom_set.token)

    assert_redirected_to library_path(locale: :fr)
    assert_not Game::CustomSet.exists?(custom_set.id)
    assert_equal "Set supprimé", flash[:toast_title]
    assert_equal "« Mes favoris » ne fait plus partie de vos sets.", flash[:notice]
  end

  test "a library set's album is named, has a goal button but no edit or delete button, no editor and no dialog, and an edit of it is not found" do
    library = create_library_set(@player)
    sign_in(@player)

    get custom_set_path(locale: :en, token: library.token)
    assert_response :success
    assert_select "title", "My Steam library · Collection · Gameble"
    assert_select "h1#set-album-heading", "My Steam library"
    assert_select "#set-album-goal form[action='/en/library/goals']"
    assert_select "[data-dialog-opener-dialog-value], dialog", false

    get custom_set_path(locale: :fr, token: library.token)
    assert_select "h1#set-album-heading", "Ma bibliothèque Steam"

    patch custom_set_path(locale: :en, token: library.token), params: { name: "x", games: slugs_of(:portal, :rare_card, :common_card) }
    assert_response :not_found
  end

  test "a visitor may not make, edit or delete a set" do
    custom_set = create_custom_set(@player)

    assert_no_difference -> { writes } do
      post custom_sets_path(locale: :en), params: { name: "x", games: slugs_of(:portal, :rare_card, :common_card) }
      assert_redirected_to home_path(locale: :en)
      patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "x", games: slugs_of(:portal, :rare_card, :common_card) }
      assert_redirected_to home_path(locale: :en)
      delete custom_set_path(locale: :en, token: custom_set.token)
      assert_redirected_to home_path(locale: :en)
    end
  end

  test "a library set stays out of MES SETS and its count" do
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    Game::CustomSetGame.insert_all!(fixture_card_ids.first(3).map { { custom_set_id: library.id, card_id: it } })
    custom_set = create_custom_set(@player)
    sign_in(@player)

    get library_path(locale: :en)

    assert_select ".custom-sets__note", "Visible to you only · 1 / 10"
    assert_equal [ "/en/library/custom-sets/#{custom_set.token}" ], css_select(".custom-sets a.set-tile").map { it["href"] }
  end

  test "deleting a library set is not found and erases nothing" do
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    sign_in(@player)

    delete custom_set_path(locale: :en, token: library.token)

    assert_response :not_found
    assert Game::CustomSet.exists?(library.id)
  end

  test "a set deleted after the policy check is not found" do
    custom_set = create_custom_set(@player)
    sign_in(@player)

    standings = Game::CustomSetStandings.method(:call)
    Game::CustomSetStandings.define_singleton_method(:call) { |*| [] }
    begin
      get custom_set_path(locale: :en, token: custom_set.token)
    ensure
      Game::CustomSetStandings.define_singleton_method(:call, standings)
    end

    assert_response :not_found
  end

  test "the album's filters narrow a custom set to its missing games and its search to a title" do
    custom_set = create_custom_set(@player, card_ids: %i[portal common_card rare_card].map { catalog_cards(it).id })
    hold(@player, catalog_card_seasons(:common_card_one).id)
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token, state: [ "missing" ])
    assert_equal [ :missing, :missing ], slots.map(&:first)
    assert_equal "1/3", css_select(".set-album__count").sole.text.squish

    get custom_set_path(locale: :en, token: custom_set.token, q: "portal")
    assert_equal [ [ :missing, "/en/cards/#{slug(:portal)}/seasons/1" ] ], slots
  end

  test "a deletion that finds the set gone returns to the collection with its refusal" do
    custom_set = create_custom_set(@player)
    found = Game::CustomSetByToken.call(custom_set.token)
    custom_set.destroy!
    sign_in(@player)
    lookup = Game::CustomSetByToken.method(:call)
    Game::CustomSetByToken.define_singleton_method(:call) { |*| found }
    begin
      delete custom_set_path(locale: :en, token: custom_set.token)
    ensure
      Game::CustomSetByToken.define_singleton_method(:call, lookup)
    end

    assert_redirected_to library_path(locale: :en)
    assert_equal Game::DeleteCustomSet.failure_message(:custom_set_not_found), flash[:alert]
  end

  test "edits, deletions and new sets are limited to twenty a minute" do
    custom_set = create_custom_set(@player)
    games = slugs_of(:common_card, :uncommon_card, :rare_card)
    sign_in(@player)

    with_counting_rate_limit(CustomSetsController) do
      21.times { |index| patch custom_set_path(locale: :fr, token: custom_set.token), params: { name: "Nom #{index}", games: } }
      assert_redirected_to library_path(locale: :fr)
      assert_equal I18n.t("custom_sets.throttled", locale: :fr), flash[:alert]
      assert_equal "Nom 19", custom_set.reload.name

      assert_no_difference -> { writes } do
        post custom_sets_path(locale: :fr), params: { name: "Autre", games: }
        delete custom_set_path(locale: :fr, token: custom_set.token)
      end
      assert_equal I18n.t("custom_sets.throttled", locale: :fr), flash[:alert]
    end
  end
end
