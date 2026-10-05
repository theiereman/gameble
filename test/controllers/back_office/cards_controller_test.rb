require "test_helper"

module BackOffice
  # The card preview of the back-office, administrators only.
  class CardsControllerTest < ActionDispatch::IntegrationTest
    setup { OmniAuth.config.test_mode = true }

    teardown do
      OmniAuth.config.mock_auth.delete(:steam)
      OmniAuth.config.test_mode = false
    end

    def sign_in(player)
      OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
      post "/auth/steam", params: { origin: "/fr" }
      follow_redirect!
      assert_equal player.id, session[:player_id]
    end

    test "an administrator sees every pair, server side and as props of the React island" do
      sign_in(accounts_players(:administrator))
      get back_office_cards_path(locale: :fr)

      assert_response :success
      pairs = Catalog::Rarity::TIERS.values.product(%w[face back], %w[small large]).map { |parts| parts.join("-") } +
        (0..4).map { |level| "rare-back-small-dust-#{level}" }
      assert_equal pairs, css_select("[data-renderer=server]").map { it["data-pair"] }
      assert_select "[data-pair=rare-back-small-dust-3] .card.card--dust-3 .card__dust"
      assert_select ".card__title", text: "Profondeurs bleues"

      props = JSON.parse(css_select("[data-turbo-mount-card-preview-component-value=CardPreview], [data-controller~=turbo-mount-card-preview]").first["data-turbo-mount-card-preview-props-value"])
      assert_equal pairs, props["pairs"].map { it["pair"] }
      assert_equal "Carte face cachée, Rare", props.dig("strings", "faceDownByRarity", "rare")
      assert_equal "Saison 12", props.dig("strings", "seasons", "12")
      assert_no_match %r{steam}i, response.body.scan(/data-card-art-url-value="[^"]*"/).join
    end

    test "a moderator is refused" do
      sign_in(accounts_players(:moderator))
      get back_office_cards_path(locale: :en)

      assert_response :forbidden
    end

    test "a visitor is asked to sign in" do
      get back_office_cards_path(locale: :en)

      assert_redirected_to home_path(locale: :en)
    end
  end
end
