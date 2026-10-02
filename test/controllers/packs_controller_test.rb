require "test_helper"
require_relative "../support/game_packs"

# The attic chest and the pack result page (R9, CAP-4): opening a pack end to
# end, the result page, and every refusal.
class PacksControllerTest < ActionDispatch::IntegrationTest
  include GamePacks

  NEW_STEAM_ID = "76561197960287930".freeze

  setup do
    Game::DrawPool.reset!
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(steam_id, origin: "/en")
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{steam_id}")
    post "/auth/steam", params: { origin: }
    follow_redirect!
    assert session[:player_id]
  end

  def chest_button
    css_select(".attic__object--chest .attic__chest-action button").sole
  end

  test "a new player finds ten packs in the chest, opens one, sees its five cards with their rarity, then nine" do
    sign_in(NEW_STEAM_ID)
    player = Accounts::Player.find_by!(steam_id: NEW_STEAM_ID)

    get home_path(locale: :en)
    assert_select ".attic__object--chest form[action='/en/packs'][method=post] button", "Open a pack (10)"

    post packs_path(locale: :en)

    pack = Game::Pack.where(player_id: player.id).where.not(opened_at: nil).sole
    assert_redirected_to "/en/packs/#{pack.token}"
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_select "h1", "Your pack, Brother"
    assert_select ".pack-result__card", 5
    rarity_names = Catalog::Rarity::TIERS.values.map { |name| I18n.t("catalog.rarity.#{name}", locale: :en) }
    css_select(".pack-result__rarity").each { |element| assert_includes rarity_names, element.text }
    titles = Catalog::CardSeasonLabels.call(pack.card_season_ids, locale: :en)
    assert_equal pack.card_season_ids.map { |id| titles.fetch(id)[:title] }, css_select(".pack-result__title").map(&:text)

    get home_path(locale: :en)
    assert_equal "Open a pack (9)", chest_button.text
  end

  test "the result page names the cards in the locale of its URL" do
    player = accounts_players(:player)
    gold = catalog_card_seasons(:gold_card_one).id
    pack = create_pack(player, cards: [ gold ] * 5, opened_at: 1.minute.ago)
    sign_in(player.steam_id)

    get pack_path(pack.token, locale: :fr)

    assert_select "h1", "Ton paquet, Confrère"
    assert_equal [ "Couronne d'or" ] * 5, css_select(".pack-result__title").map(&:text)
    assert_equal [ "Or" ] * 5, css_select(".pack-result__rarity").map(&:text)
  end

  test "another player's pack, an unopened pack and an unknown token are not found" do
    player = accounts_players(:player)
    foreign = create_pack(accounts_players(:moderator), opened_at: 1.minute.ago)
    unopened = create_pack(player)
    sign_in(player.steam_id)

    [ foreign.token, unopened.token, "unknown-token" ].each do |token|
      get pack_path(token, locale: :en)

      assert_response :not_found, token
    end
  end

  test "a visitor cannot read a pack" do
    pack = create_pack(accounts_players(:player), opened_at: 1.minute.ago)

    get pack_path(pack.token, locale: :en)

    assert_response :not_found
  end

  test "an empty chest shows a disabled button, and opening is refused with an alert" do
    player = accounts_players(:player)
    create_pack(player, available_at: 1.day.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :fr)
    assert_equal "Aucun paquet", chest_button.text
    assert chest_button["disabled"]
    assert_select ".attic__object--chest form", false

    post packs_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.no_pack_available", locale: :fr), flash[:alert]
    assert_equal 0, Game::Holding.where(player_id: player.id).count
  end

  test "a visitor sees the chest's button and is sent to sign in when pressing it; nothing changes" do
    get home_path(locale: :en)
    assert_select ".attic__object--chest form[action='/en/packs'][method=post] button", "Open a pack"

    assert_no_difference -> { Game::Pack.where.not(opened_at: nil).count } do
      post packs_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
  end

  test "more than 30 openings a minute by one player are sent back to the attic with an alert" do
    player = accounts_players(:player)
    31.times { |index| create_pack(player, available_at: (index + 1).minutes.ago) }
    sign_in(player.steam_id)
    # The test cache store counts nothing: the rate limit's store counts in
    # memory for this test.
    memory = ActiveSupport::Cache::MemoryStore.new
    store = PacksController.cache_store
    store.define_singleton_method(:increment) { |*args, **options| memory.increment(*args, **options) }
    begin
      30.times do
        post packs_path(locale: :en)
        assert_response :see_other
        assert_match %r{/en/packs/}, response.location
      end

      post packs_path(locale: :en)
    ensure
      store.singleton_class.remove_method(:increment)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("packs.create.throttled", locale: :en), flash[:alert]
    assert_equal 1, Game::BankSummary.call(player)[:available]
  end
end
