require "test_helper"
require_relative "../support/steam_sign_in"

# Adding a card to the profile showcase and taking it out, from its detail:
# the answers in Turbo Stream, HTML and JSON, and every refusal.
class ShowcasesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one).id
  end

  def hold(card_season_id, quantity: 1)
    Game::Holding.create!(player_id: @player.id, card_season_id:, quantity:)
  end

  def showcase_path(slug: "portal", number: 1, locale: :en) = card_showcase_path(locale:, slug:, number:)

  def detail_path(locale: :en) = card_season_path(locale:, slug: "portal", number: 1)

  def chosen = Game::ChosenShowcase.call(@player)

  def assert_json_error(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, response.parsed_body)
  end

  def assert_toast(message)
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=append][target=toasts] template .toast--alert .toast__message", message
  end

  test "a held card is added and taken out, each answer leading back to its detail" do
    hold(@portal)
    sign_in(@player)

    post showcase_path, headers: { "HTTP_REFERER" => detail_path }
    assert_redirected_to detail_path
    assert_response :see_other
    assert_nil flash[:alert]
    assert_equal [ @portal ], chosen

    delete showcase_path, headers: { "HTTP_REFERER" => detail_path }
    assert_redirected_to detail_path
    assert_response :see_other
    assert_empty chosen
  end

  test "from Turbo the change leads back to the detail; in JSON it answers no content" do
    hold(@portal)
    sign_in(@player)

    post showcase_path, as: :turbo_stream
    assert_redirected_to detail_path
    assert_equal [ @portal ], chosen

    delete showcase_path, as: :json
    assert_response :no_content
    assert_empty chosen
  end

  test "a card not held, one already there or not there is refused with its message and writes nothing" do
    hold(@portal)
    sign_in(@player)
    post showcase_path, as: :json

    assert_no_difference -> { Game::ShowcaseEntry.count + Rails.configuration.event_store.read.count } do
      post showcase_path, as: :json
      assert_json_error :unprocessable_content, "card_already_showcased", "This card is already in your showcase."

      post showcase_path(slug: "golden-crown"), as: :json
      assert_json_error :unprocessable_content, "card_not_owned", "You do not own this card."

      delete showcase_path(slug: "golden-crown", locale: :fr), as: :turbo_stream
      assert_response :unprocessable_content
      assert_toast "Cette carte n'est pas dans votre vitrine."

      post showcase_path(slug: "golden-crown"), headers: { "HTTP_REFERER" => detail_path }
      assert_redirected_to detail_path
      assert_equal "You do not own this card.", flash[:alert]
    end
  end

  test "a full showcase refuses a sixth card with the showcase-full line" do
    hold(@portal)
    sign_in(@player)
    ids = catalog_card_seasons(:common_card_one, :uncommon_card_one, :rare_card_one, :legendary_card_one).map(&:id)
    ids.each_with_index { |id, position| Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id: id, position:) }
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    extra = Catalog::CardSeason.create!(card: catalog_cards(:common_card), season:, prestige_score: 0.5, rating: 80.0)
    Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id: extra.id, position: 4)

    post showcase_path, as: :json

    assert_json_error :unprocessable_content, "showcase_full", "Showcase full: remove a card to add another."
    assert_equal 5, chosen.size
  end

  test "an unknown card or season is not found" do
    sign_in(@player)

    post showcase_path(slug: "no-such-game"), as: :json
    assert_json_error :not_found, "not_found", "This card does not exist."

    delete showcase_path(number: 9), as: :json
    assert_json_error :not_found, "not_found", "This card does not exist."

    post showcase_path(slug: "no-such-game"), as: :turbo_stream
    assert_response :not_found
    assert_toast "This card does not exist."

    delete showcase_path(slug: "no-such-game")
    assert_response :not_found
  end

  test "a visitor is sent to the landing, or answered 401 in JSON; nothing written" do
    assert_no_difference -> { Game::ShowcaseEntry.count } do
      post showcase_path
      assert_redirected_to landing_path(locale: :en)
      assert_nil flash[:alert]

      delete showcase_path, as: :json
      assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    end
  end

  test "the route takes the slug and the season's number, never an id" do
    assert_equal "/fr/cards/portal/seasons/1/showcase", card_showcase_path(locale: :fr, slug: "portal", number: 1)
  end

  def choose(*fixtures)
    fixtures.map { catalog_card_seasons(it).id }.each do |id|
      hold(id)
      Game::AddToShowcase.new.call(player: @player, card_season_id: id).value!
    end
  end

  def profile_path(locale: :en) = brother_path(locale:, token: @player.token)

  test "a move leads back to the profile, names the card and the direction in the flash, and reorders the showcase" do
    choose(:portal_one, :common_card_one, :uncommon_card_one)
    sign_in(@player)

    patch showcase_path, params: { direction: "later" }, headers: { "HTTP_REFERER" => profile_path }

    assert_redirected_to profile_path
    assert_response :see_other
    assert_nil flash[:alert]
    assert_equal({ "slug" => "portal", "number" => "1", "direction" => "later" }, flash[:moved_showcase_card])
    assert_equal catalog_card_seasons(:common_card_one, :portal_one, :uncommon_card_one).map(&:id), chosen
  end

  test "without a referrer a move leads to the owner's profile; from Turbo too; in JSON it answers no content" do
    choose(:portal_one, :common_card_one)
    sign_in(@player)

    patch showcase_path, params: { direction: "later" }
    assert_redirected_to profile_path

    patch showcase_path, params: { direction: "earlier" }, as: :turbo_stream
    assert_redirected_to profile_path
    assert_equal catalog_card_seasons(:portal_one, :common_card_one).map(&:id), chosen

    patch showcase_path, params: { direction: "later" }, as: :json
    assert_response :no_content
    assert_equal catalog_card_seasons(:common_card_one, :portal_one).map(&:id), chosen
  end

  test "a move past the edge, of a card not in the showcase or in no direction is refused with its message and writes nothing" do
    choose(:portal_one, :common_card_one)
    sign_in(@player)

    assert_no_changes -> { Game::ShowcaseEntry.order(:id).pluck(:position, :updated_at) + [ Rails.configuration.event_store.read.count ] } do
      patch showcase_path, params: { direction: "earlier" }, as: :json
      assert_json_error :unprocessable_content, "showcase_edge", "This card cannot move any further."

      patch showcase_path(slug: "golden-crown"), params: { direction: "later" }, as: :json
      assert_json_error :unprocessable_content, "card_not_showcased", "This card is not in your showcase."

      patch showcase_path, params: { direction: "up" }, as: :json
      assert_json_error :unprocessable_content, "unknown_direction", "Unknown direction."

      patch showcase_path(locale: :fr), params: { direction: "earlier" }, as: :turbo_stream
      assert_response :unprocessable_content
      assert_toast "Cette carte ne peut pas aller plus loin."

      patch showcase_path, params: { direction: "earlier" }, headers: { "HTTP_REFERER" => profile_path }
      assert_redirected_to profile_path
      assert_equal "This card cannot move any further.", flash[:alert]
      assert_nil flash[:moved_showcase_card]
    end
  end

  test "a move of an unknown card is not found" do
    sign_in(@player)

    patch showcase_path(slug: "no-such-game"), params: { direction: "later" }, as: :json
    assert_json_error :not_found, "not_found", "This card does not exist."

    patch showcase_path(slug: "no-such-game"), params: { direction: "later" }
    assert_response :not_found
  end

  test "a visitor's move is refused like an addition; nothing written" do
    choose(:portal_one, :common_card_one)

    assert_no_changes -> { chosen } do
      patch showcase_path, params: { direction: "later" }
      assert_redirected_to landing_path(locale: :en)

      patch showcase_path, params: { direction: "later" }, as: :json
      assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    end
  end

  test "a card dropped at a place in JSON answers no content and the showcase takes the new order, no flash" do
    choose(:portal_one, :common_card_one, :uncommon_card_one)
    sign_in(@player)

    patch showcase_path, params: { position: 2 }, as: :json

    assert_response :no_content
    assert_nil flash[:moved_showcase_card]
    assert_equal catalog_card_seasons(:common_card_one, :uncommon_card_one, :portal_one).map(&:id), chosen

    patch showcase_path, params: { position: "0" }, headers: { "HTTP_REFERER" => profile_path }
    assert_redirected_to profile_path
    assert_equal catalog_card_seasons(:portal_one, :common_card_one, :uncommon_card_one).map(&:id), chosen
  end

  test "a drop outside the showcase, at no whole place or of a card not in the showcase is refused with its message and writes nothing" do
    choose(:portal_one, :common_card_one)
    sign_in(@player)

    assert_no_changes -> { Game::ShowcaseEntry.order(:id).pluck(:position, :updated_at) + [ Rails.configuration.event_store.read.count ] } do
      [ 2, -1, "first", "" ].each do |position|
        patch showcase_path, params: { position: }, as: :json
        assert_json_error :unprocessable_content, "position_out_of_range", "The showcase has no such place."
      end

      patch showcase_path(slug: "golden-crown"), params: { position: 0 }, as: :json
      assert_json_error :unprocessable_content, "card_not_showcased", "This card is not in your showcase."

      patch showcase_path(locale: :fr), params: { position: 5 }, as: :json
      assert_json_error :unprocessable_content, "position_out_of_range", "La vitrine n'a pas cette place."
    end
  end

  test "a visitor's drop is refused; nothing written" do
    choose(:portal_one, :common_card_one)

    assert_no_changes -> { chosen } do
      patch showcase_path, params: { position: 1 }, as: :json
      assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    end
  end
end
