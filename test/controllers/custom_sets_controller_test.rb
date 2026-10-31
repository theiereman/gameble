require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/custom_sets"
require_relative "../support/steam_sign_in"

# A player's own sets through HTTP: the album, its author's only; the
# picker's form, its search and its refusals; renaming and deleting.
class CustomSetsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GameSets
  include Holdings
  include CustomSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def slug(name) = catalog_cards(name).slug

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

  def checked_games = css_select("input[type=checkbox][name='games[]'][checked]").map { it["value"] }

  def unchecked_games = css_select("input[type=checkbox][name='games[]']:not([checked])").map { it["value"] }

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
      assert_select "a.button[href='/en/library/custom-sets/#{custom_set.token}/edit']", "Edit"
      assert_select "form.button-form[action='/en/library/custom-sets/#{custom_set.token}'][data-turbo-confirm='Delete “Mes favoris”?']" do
        assert_select "input[name=_method][value=delete]"
        assert_select "button", "Delete"
      end
    end
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

  test "no database id of the set or its games is in the album, the list or the picker" do
    %w[game_custom_sets_id_seq game_custom_set_games_id_seq].each do |sequence|
      ActiveRecord::Base.connection.execute("SELECT setval('#{sequence}', #{7_000_000_000 + SecureRandom.random_number(1_000_000)})")
    end
    custom_set = create_custom_set(@player)
    ids = [ custom_set.id, *Game::CustomSetGame.where(custom_set_id: custom_set.id).pluck(:id, :card_id).flatten ].map(&:to_s)
    sign_in(@player)

    [ custom_set_path(locale: :en, token: custom_set.token), library_path(locale: :en), edit_custom_set_path(locale: :en, token: custom_set.token) ].each do |path|
      get path
      assert_response :success
      ids.each { assert_no_match(/\b#{it}\b/, response.body, path) }
    end
  end

  test "another player's set is refused without its name; a visitor is sent to the landing; an unknown token is not found" do
    custom_set = create_custom_set(accounts_players(:moderator), name: "Secret garden")
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)
    assert_response :forbidden
    assert_no_match(/Secret garden/, response.body)

    get edit_custom_set_path(locale: :en, token: custom_set.token)
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

  test "the empty picker: the name, the search with its button first, nothing selected, save and cancel" do
    sign_in(@player)

    get new_custom_set_path(locale: :fr)

    assert_response :success
    assert_select "title", "Nouveau set · Collection · Gameble"
    assert_select "h1", "Nouveau set"
    assert_select "form.custom-set-picker[action='/fr/library/custom-sets'][method=post][data-turbo=false]" do
      assert_select "input#custom-set-name[name=name][maxlength='40']"
      assert_select "label[for=custom-set-name]", "Nom du set"
      assert_select "button[type=submit][formaction='/fr/library/custom-sets/picker']", "Chercher"
      assert_equal "Chercher", css_select("form.custom-set-picker button[type=submit]").first.text
      assert_select "legend", "Sélectionnés · 0"
      assert_select ".custom-set-picker__counter", "0 jeu · 3 à 50"
      assert_select "a[href='/fr/library']", "Annuler"
      assert_select "button[type=submit]", "Enregistrer"
    end
    assert_select "[style]", false
  end

  test "the picker's search keeps the name and the checked games, lists the unchecked results, and writes nothing" do
    sign_in(@player)

    assert_no_difference -> { writes } do
      post custom_set_picker_path(locale: :en), params: { name: "Mes favoris", q: "seed", games: [ slug(:portal), "unknown" ] }
    end

    assert_response :success
    assert_select "input#custom-set-name[value='Mes favoris']"
    assert_select "input#custom-set-query[value=seed]"
    assert_equal [ slug(:portal) ], checked_games
    assert_select "legend", "Selected · 1"
    assert_select ".custom-set-picker__counter", "1 game · 3 to 50"
    assert_empty unchecked_games

    _season, card_season_ids = published_cards(30)
    found = Catalog::Card.where(id: Catalog::CardSeason.where(id: card_season_ids).select(:card_id)).order(:id).pluck(:slug)
    post custom_set_picker_path(locale: :en), params: { name: "Mes favoris", q: "seed", games: [ found.first ] }
    assert_equal [ found.first ], checked_games
    assert_equal 24, unchecked_games.size
    assert_empty unchecked_games & [ found.first ]
    assert_empty unchecked_games - found
    assert_select ".custom-set-picker__none", false

    post custom_set_picker_path(locale: :fr), params: { name: "x", q: "zzzz" }
    assert_select ".custom-set-picker__none", "Aucun jeu trouvé pour « zzzz »."
  end

  test "saving three published games creates the set and opens its album" do
    sign_in(@player)

    assert_difference -> { Game::CustomSet.count }, 1 do
      post custom_sets_path(locale: :en), params: { name: "Mes favoris", games: [ slug(:portal), slug(:rare_card), slug(:common_card) ] }
    end

    custom_set = Game::CustomSet.last
    assert_redirected_to custom_set_path(locale: :en, token: custom_set.token)
    assert_equal %i[portal rare_card common_card].map { catalog_cards(it).id }, Game::CustomSetGame.where(custom_set_id: custom_set.id).order(:id).pluck(:card_id)

    get library_path(locale: :en)
    assert_select "section.custom-sets[aria-labelledby=custom-sets-title]" do
      assert_select "h2#custom-sets-title", "My sets"
      assert_select ".custom-sets__note", "Visible to you only · 1 / 10"
      assert_select "a.custom-sets__link[href='/en/library/custom-sets/#{custom_set.token}']" do
        assert_select ".custom-sets__name", "Mes favoris"
        assert_select ".custom-sets__count", "0/3"
        assert_select ".visually-hidden", "0 cards out of 3"
      end
      assert_select "a.button[href='/en/library/custom-sets/new']", "+ New set"
    end
  end

  test "a refusal renders the form again with its message, the name and the games kept, and writes nothing" do
    sign_in(@player)

    assert_no_difference -> { writes } do
      post custom_sets_path(locale: :fr), params: { name: "Mes favoris", games: [ slug(:portal), slug(:rare_card) ] }
    end

    assert_response :unprocessable_content
    assert_select ".custom-set-form__refusal[role=alert]", "3 jeux au moins : ajoutez des jeux pour enregistrer le set."
    assert_select "input#custom-set-name[value='Mes favoris']"
    assert_equal [ slug(:portal), slug(:rare_card) ], checked_games

    post custom_sets_path(locale: :en), params: { name: "x", games: [ slug(:portal), slug(:rare_card), "unknown" ] }
    assert_response :unprocessable_content
    assert_select ".custom-set-form__refusal", "A chosen game is not in the catalog. Reload the page and try again."
  end

  test "ten sets: no new set button" do
    10.times { create_custom_set(@player, name: "Set #{it}") }
    sign_in(@player)

    get library_path(locale: :en)

    assert_select ".custom-sets__note", "Visible to you only · 10 / 10"
    assert_select ".custom-sets__link", 10
    assert_select ".custom-sets a[href='/en/library/custom-sets/new']", false
  end

  test "the rename form holds the name only; a rename returns to the album, a refusal shows its message" do
    create_custom_set(@player, name: "Autre")
    custom_set = create_custom_set(@player)
    sign_in(@player)

    get edit_custom_set_path(locale: :en, token: custom_set.token)
    assert_response :success
    assert_select "h1", "Edit the set"
    assert_select "form[action='/en/library/custom-sets/#{custom_set.token}'][data-turbo=false]" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input#custom-set-name[value='Mes favoris']"
      assert_select "input[name='games[]'], input[name=q]", false
    end

    patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "AUTRE" }
    assert_response :unprocessable_content
    assert_select ".custom-set-form__refusal", "Name taken: another of your sets has this name."
    assert_select "input#custom-set-name[value=AUTRE]"

    patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "Jeux du soir" }
    assert_redirected_to custom_set_path(locale: :en, token: custom_set.token)
    assert_equal "Jeux du soir", custom_set.reload.name
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

  test "a library set's album has no edit or delete, and its edit form is not found" do
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    Game::CustomSetGame.insert_all!(fixture_card_ids.first(3).map { { custom_set_id: library.id, card_id: it } })
    sign_in(@player)

    get custom_set_path(locale: :en, token: library.token)
    assert_response :success
    assert_select ".set-album__actions", false

    get edit_custom_set_path(locale: :en, token: library.token)
    assert_response :not_found
  end

  test "a visitor may not make, rename or delete a set" do
    custom_set = create_custom_set(@player)

    get new_custom_set_path(locale: :en)
    assert_redirected_to home_path(locale: :en)

    assert_no_difference -> { writes } do
      post custom_sets_path(locale: :en), params: { name: "x", games: [ slug(:portal), slug(:rare_card), slug(:common_card) ] }
      patch custom_set_path(locale: :en, token: custom_set.token), params: { name: "x" }
      delete custom_set_path(locale: :en, token: custom_set.token)
    end
  end

  test "the picker and the rename form carry the Sets screen label" do
    custom_set = create_custom_set(@player)
    sign_in(@player)

    get new_custom_set_path(locale: :en)
    assert_select "header.top-bar[data-screen-label=Sets]"

    get edit_custom_set_path(locale: :en, token: custom_set.token)
    assert_select "header.top-bar[data-screen-label=Sets]"
  end

  test "a visitor's picker search is sent to the landing" do
    post custom_set_picker_path(locale: :en), params: { name: "x", q: "seed" }

    assert_redirected_to home_path(locale: :en)
  end

  test "fifty-one picked games reach the fifty-games refusal and write nothing" do
    _season, card_season_ids = published_cards(51)
    slugs = Catalog::Card.where(id: Catalog::CardSeason.where(id: card_season_ids).select(:card_id)).order(:id).pluck(:slug)
    sign_in(@player)

    assert_no_difference -> { writes } do
      post custom_sets_path(locale: :en), params: { name: "Tout", games: slugs }
    end

    assert_response :unprocessable_content
    assert_select ".custom-set-form__refusal", "50 games at most: remove a game to add another."
  end

  test "a library set stays out of MES SETS and its count" do
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    Game::CustomSetGame.insert_all!(fixture_card_ids.first(3).map { { custom_set_id: library.id, card_id: it } })
    custom_set = create_custom_set(@player)
    sign_in(@player)

    get library_path(locale: :en)

    assert_select ".custom-sets__note", "Visible to you only · 1 / 10"
    assert_equal [ "/en/library/custom-sets/#{custom_set.token}" ], css_select(".custom-sets__link").map { it["href"] }
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

  test "renames, deletions and new sets are limited to twenty a minute" do
    custom_set = create_custom_set(@player)
    sign_in(@player)

    with_counting_rate_limit(CustomSetsController) do
      21.times { |index| patch custom_set_path(locale: :fr, token: custom_set.token), params: { name: "Nom #{index}" } }
      assert_redirected_to library_path(locale: :fr)
      assert_equal I18n.t("custom_sets.throttled", locale: :fr), flash[:alert]
      assert_equal "Nom 19", custom_set.reload.name

      assert_no_difference -> { writes } do
        post custom_sets_path(locale: :fr), params: { name: "Autre", games: fixture_card_ids.first(3).map { Catalog::Card.find(it).slug } }
        delete custom_set_path(locale: :fr, token: custom_set.token)
      end
      assert_equal I18n.t("custom_sets.throttled", locale: :fr), flash[:alert]
    end
  end
end
