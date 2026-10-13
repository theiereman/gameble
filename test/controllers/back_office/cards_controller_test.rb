require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The card preview of the back-office, administrators only.
  class CardsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn
    SPECIMENS = Catalog::Rarity::TIERS.values.product(%w[s m l xl]).map { |parts| parts.join("-") } +
      Catalog::Rarity::TIERS.values.map { |rarity| "#{rarity}-m-booster" }

    def sign_in_origin = "/fr"

    test "an administrator sees every tier's face at each size, then at m with the booster's effects, all from the server" do
      sign_in(accounts_players(:administrator))
      get back_office_cards_path(locale: :fr)

      assert_response :success
      assert_equal SPECIMENS, css_select("[data-specimen]").map { it["data-specimen"] }
      SPECIMENS.each do |specimen|
        rarity, size, booster = specimen.split("-")
        assert_select "[data-specimen=#{specimen}] > .card.card--#{size}.card--rarity-#{rarity}#{".card--booster" if booster}", 1
        assert_select "[data-specimen=#{specimen}] .card--booster", booster ? 1 : 0
      end
      assert_select "[data-specimen=rare-s] .card__title", text: "Profondeurs bleues"
      assert_select "[data-specimen=rare-xl] .card__genre", text: "Réflexion"
      assert_select "[data-specimen=common-m] .card__genre", 0
      assert_select "[data-specimen=epic-m] .card__number", 0
      assert_select "[data-specimen=rare-l] .card__number", "S12 · #1 000 000"
      assert_select "[data-specimen=legendary-m-booster] figcaption", "Légendaire, taille M, booster"
      assert_select "[data-turbo-mount-card-preview-component-value], [data-controller~=turbo-mount-card-preview]", 0
      assert_select "[style]", 0
      assert_no_match %r{steam}i, response.body.scan(/data-card-art-url-value="[^"]*"/).join
    end

    test "a moderator is refused" do
      sign_in(accounts_players(:moderator))
      get back_office_cards_path(locale: :en)

      assert_response :forbidden
    end

    test "a visitor and a player get the 404 of an unknown address" do
      get back_office_cards_path(locale: :en)
      assert_unknown_address

      sign_in(accounts_players(:player))
      get back_office_cards_path(locale: :en)
      assert_unknown_address
    end
  end
end
