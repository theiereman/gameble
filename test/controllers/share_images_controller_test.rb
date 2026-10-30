require "test_helper"
require_relative "../support/share_image_art"
require_relative "../support/steam_sign_in"

# A shared card's preview image, by token: a PNG for any browser or
# crawler, signed out or in, cacheable by anyone for a year, no cookie;
# an unknown or malformed token is not found.
class ShareImagesControllerTest < ActionDispatch::IntegrationTest
  include ShareImageArt
  include SteamSignIn

  USER_AGENTS = [
    "Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 11.6; rv:92.0) Gecko/20100101 Firefox/92.0",
    "Twitterbot/1.0",
    "WhatsApp/2.23.20.0 A",
    "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
  ].freeze

  setup do
    @png = tiny_png
    @share_image = store_share_image(catalog_card_seasons(:rare_card_one).id, "en", png: @png)
  end

  def image_path = share_image_path(token: @share_image.token, locale: nil)

  test "the image's path holds its token only, outside any locale" do
    assert_equal "/share-images/#{@share_image.token}.png", image_path
  end

  test "any browser or crawler gets the PNG, signed out, public for a year, without a cookie" do
    USER_AGENTS.each do |user_agent|
      get image_path, headers: { "User-Agent" => user_agent }

      assert_response :success, user_agent
      assert_equal "image/png", response.media_type
      assert_equal @png, response.body
      assert_equal "max-age=31536000, public, immutable", response.headers["Cache-Control"]
      assert_nil response.headers["Set-Cookie"], user_agent
    end

    head image_path
    assert_response :success
  end

  test "search engines are told not to index the image, even with search indexing on" do
    indexing_was = Rails.configuration.x.search_indexing
    Rails.configuration.x.search_indexing = true

    get image_path

    assert_response :success
    assert_equal "noindex", response.headers["X-Robots-Tag"]
  ensure
    Rails.configuration.x.search_indexing = indexing_was
  end

  test "Active Storage's own routes, which carry signed database ids, are not drawn" do
    paths = Rails.application.routes.routes.map { it.path.spec.to_s }
    assert_empty paths.grep(%r{\A/rails/active_storage})

    post "/rails/active_storage/direct_uploads", params: { blob: { filename: "a.png", byte_size: 1, checksum: "x", content_type: "image/png" } }
    assert_response :not_found
  end

  test "a signed-in player gets the same image, and the request leaves their session alone" do
    sign_in(accounts_players(:player))

    assert_no_enqueued_jobs(only: Accounts::NoteLastSeenJob) { get image_path }

    assert_response :success
    assert_equal @png, response.body
    assert_nil response.headers["Set-Cookie"]
  end

  test "an unknown or malformed token is not found" do
    get share_image_path(token: "A" * 24, locale: nil)
    assert_response :not_found

    [ "/share-images/#{@share_image.token}", "/share-images/#{@share_image.token}.jpg", "/share-images/#{@share_image.id}.png",
      "/en/share-images/#{@share_image.token}.png" ].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "a replaced image's old token is not found" do
    old_token = @share_image.token
    store_share_image(@share_image.card_season_id, "en", fingerprint: "d" * 64)

    get share_image_path(token: old_token, locale: nil)

    assert_response :not_found
  end
end
