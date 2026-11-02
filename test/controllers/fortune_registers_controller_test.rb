require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The Register of the Privileged and the Fortune section of a profile,
# both readable without an account.
class FortuneRegistersControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
  end

  def open_cards(player, tier)
    create_pack(player, cards: [ fixture_tier_ids[tier - 1] ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  test "the week's register ranks the luckiest first, marks the Privileged and hides the names of non-public profiles" do
    hidden = Accounts::Player.create!(steam_id: "76561197960400101", persona_name: "Secret", visibility: :private)
    open_cards(@player, 5)
    open_cards(hidden, 1)

    get fortune_register_path(locale: :en)

    assert_response :success
    assert_select "h1", "Register of the Privileged"
    assert_select ".register__privileged-count", "1 Privileged among 2 members who opened a capsule this week"
    assert_select ".register-row", 2
    assert_select ".register-row:nth-child(1).register-row--privileged a.register-row__name[href=?]", brother_path(locale: :en, token: @player.token), "Hugo"
    assert_select ".register-row:nth-child(1) .register-row__index.fortune-index--up", "+500"
    assert_select ".register-row:nth-child(1) .register-row__label", "Indecently Lucky"
    assert_select ".register-row:nth-child(2) .register-row__name--hidden", "Private member"
    assert_select ".register-row:nth-child(2) .fortune__privileged", false
    assert_no_match "Secret", response.body
    assert_select "[style]", false
  end

  test "the all-time tab, in French, and an empty week" do
    travel_to(2.weeks.ago) { open_cards(@player, 3) }

    get fortune_register_path(locale: :fr, period: "all_time")

    assert_select "h1", "Registre des Privilégiés"
    assert_select ".register__tabs a[aria-current=true]", "Depuis toujours"
    assert_select ".register-row", 1
    assert_select ".register__privileged-count", "Aucun Privilégié pour l'instant cette semaine"

    get fortune_register_path(locale: :en)

    assert_select ".register__empty", "No member has opened a capsule this week yet."
  end

  test "a profile's Fortune section: the week's index, label, rank, Privileged mark and the figures behind it" do
    open_cards(@player, 5)

    get brother_path(locale: :en, token: @player.token)

    assert_response :success
    assert_select "turbo-frame#profile-fortune" do
      assert_select "h2", "Fortune"
      assert_select ".fortune__tabs a[aria-current=true]", "This week"
      assert_select ".fortune-index__value", "+500"
      assert_select ".fortune__label", /Indecently Lucky/
      assert_select ".fortune__privileged", "PRIVILEGED"
      assert_select ".fortune__rank a[href=?]", fortune_register_path(locale: :en), "Rank 1 of 1"
      assert_select ".profile-figure", text: /Points earned\s*500/
      assert_select ".profile-figure--rarity-5 .profile-figure__value", "5"
    end
  end

  test "a profile's all-time tab, and a period without any pack" do
    travel_to(2.weeks.ago) { open_cards(@player, 1) }

    get brother_path(locale: :en, token: @player.token, fortune: "all_time")
    assert_select ".fortune__tabs a[aria-current=true]", "All time"
    assert_select ".fortune-index__value", /\A-\d+\z/
    assert_select ".fortune__privileged", false

    get brother_path(locale: :en, token: @player.token)
    assert_select ".fortune__empty", "No capsule opened this week yet."
  end
end
