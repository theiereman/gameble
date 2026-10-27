require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

# Reposting a card from its detail, the booster and the hub: the answers in
# Turbo Stream, HTML and JSON, and every refusal.
class RepostsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one).id
  end

  def hold(card_season_id, quantity: 1)
    Game::Holding.create!(player_id: @player.id, card_season_id:, quantity:)
  end

  def repost_path(slug: "portal", number: 1, locale: :en) = card_repost_path(locale:, slug:, number:)

  def reposts = Game::FeedEntry.where(kind: "repost")

  def assert_json_error(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, response.parsed_body)
  end

  def assert_toast(tone, message)
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=append][target=toasts] template .toast--#{tone} .toast__message", message
  end

  test "from Turbo, a held card is reposted with a toast, in French and English" do
    hold(@portal)
    sign_in(@player)

    post repost_path(locale: :fr), as: :turbo_stream

    assert_response :success
    assert_toast :notice, "Carte repostée dans le fil."
    entry = reposts.sole
    assert_equal [ @player.id, @portal ], [ entry.player_id, entry.card_season_id ]
  end

  test "without JavaScript the repost goes back to the card with a flash" do
    hold(@portal)
    sign_in(@player)

    post repost_path, headers: { "HTTP_REFERER" => card_path(locale: :en, slug: "portal") }

    assert_redirected_to card_path(locale: :en, slug: "portal")
    assert_response :see_other
    assert_equal "Card reposted to the feed.", flash[:notice]
    assert_equal 1, reposts.count
  end

  test "in JSON a repost answers its message, a card not held its error" do
    hold(@portal)
    sign_in(@player)

    post repost_path, as: :json
    assert_response :success
    assert_equal({ "message" => "Card reposted to the feed." }, response.parsed_body)

    assert_no_difference -> { Game::FeedEntry.count } do
      post repost_path(slug: "golden-crown"), as: :json
    end
    assert_json_error :unprocessable_content, "card_not_owned", "You do not own this card."
  end

  test "a card not held is refused with a toast and writes nothing" do
    hold(@portal, quantity: 0)
    sign_in(@player)

    assert_no_difference -> { Game::FeedEntry.count + Rails.configuration.event_store.read.of_type([ Game::CardReposted ]).count } do
      post repost_path(locale: :fr), as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_toast :alert, "Vous ne possédez pas cette carte."
  end

  test "a repost beyond the limits is refused with the translated message in both locales" do
    hold(@portal)
    sign_in(@player)
    post repost_path, as: :json
    assert_response :success

    assert_no_difference -> { Game::FeedEntry.count } do
      post repost_path(locale: :fr), as: :turbo_stream
      assert_response :unprocessable_content
      assert_toast :alert, "Vous avez déjà reposté cette carte aujourd'hui. Réessayez demain."

      post repost_path, as: :json
      assert_json_error :unprocessable_content, "already_reposted", "You reposted this card today. Try again tomorrow."
    end

    Game::FeedEntry.where(kind: "repost").delete_all
    Game::RepostCard::HOURLY_LIMIT.times do
      Game::FeedEntry.create!(kind: "repost", player_id: @player.id, card_season_id: @portal, rarity: 1, notable: true,
        occurred_at: 1.minute.ago)
    end
    assert_no_difference -> { Game::FeedEntry.count } do
      post repost_path, as: :json
      assert_json_error :unprocessable_content, "repost_limit_reached", "You have reposted a lot this past hour. Try again later."
    end
  end

  test "an unknown card or season is not found" do
    hold(@portal)
    sign_in(@player)

    post repost_path(slug: "no-such-game"), as: :json
    assert_json_error :not_found, "not_found", "This card does not exist."

    post repost_path(number: 9), as: :json
    assert_json_error :not_found, "not_found", "This card does not exist."

    post repost_path(number: "one"), as: :json
    assert_json_error :not_found, "not_found", "This card does not exist."

    post repost_path(slug: "no-such-game"), as: :turbo_stream
    assert_response :not_found
    assert_toast :alert, "This card does not exist."

    post repost_path(slug: "no-such-game")
    assert_response :not_found

    assert_equal 0, reposts.count
  end

  test "a visitor is sent to the landing, or answered 401 in JSON; nothing written" do
    assert_no_difference -> { Game::FeedEntry.count } do
      post repost_path

      assert_redirected_to home_path(locale: :en)
      assert_nil flash[:alert]

      post repost_path, as: :json
      assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    end
  end

  test "thirty reposts a minute are answered; the thirty-first is throttled with Retry-After" do
    hold(@portal)
    sign_in(@player)

    with_counting_rate_limit(RepostsController) do
      30.times do
        post repost_path, as: :json
        assert_not_equal 429, response.status
      end

      post repost_path, as: :json
      assert_json_error :too_many_requests, "throttled", "Too many reposts in a minute. Try again in a moment."
      assert_equal "60", response.headers["Retry-After"]
    end
    assert_equal 1, reposts.count
  end

  test "the route takes the slug and the season's number, never an id" do
    assert_equal "/fr/cards/portal/seasons/1/repost", card_repost_path(locale: :fr, slug: "portal", number: 1)
  end
end
