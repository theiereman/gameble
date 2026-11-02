require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The Register of the Privileged, a dashboard of every ranked player, and
# the Fortune section of a profile, both readable without an account.
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

  test "the week's dashboard shows every player as a tile: luck, capsules, collection and showcase; private ones keep only their luck" do
    hidden = Accounts::Player.create!(steam_id: "76561197960400101", persona_name: "Secret", visibility: :private)
    open_cards(@player, 5)
    open_cards(@player, 1)
    open_cards(hidden, 1)
    Game::AddToShowcase.new.call(player: @player, card_season_id: fixture_tier_ids[4]).value!

    get fortune_register_path(locale: :en)

    assert_response :success
    assert_select "h1", "Register of the Privileged"
    assert_select ".register__summary .profile-figure", text: /Active this week\s*2/
    assert_select ".register__summary .profile-figure", text: /Capsules this week\s*3/
    assert_select ".register__summary .profile-figure", text: %r{Privileged\s*1/2}
    assert_select ".player-tile", 2
    assert_select ".player-tile:nth-child(1).player-tile--privileged" do
      assert_select "a.player-tile__name[href=?]", brother_path(locale: :en, token: @player.token), "Hugo"
      assert_select ".player-tile__rank", "#1"
      assert_select ".player-tile__label", "Indecently Lucky"
      assert_select ".fortune-index--up", "+500"
      assert_select ".profile-figure", text: /Capsules\s*2/
      assert_select ".profile-figure--rarity-5 .profile-figure__value", "1"
      assert_select ".player-tile__showcase .card", 1
    end
    assert_select ".player-tile:nth-child(2)" do
      assert_select ".player-tile__name--hidden", "Private member"
      assert_select ".fortune__privileged", false
      assert_select ".player-tile__rarities", false
      assert_select ".player-tile__no-showcase", "This member keeps their collection private."
    end
    assert_no_match "Secret", response.body
    assert_select "[style]", false
  end

  test "the order by capsules, the all-time tab in French, and an empty week" do
    travel_to(2.weeks.ago) { open_cards(@player, 3) }
    sign_in(@player)

    get fortune_register_path(locale: :fr, period: "all_time", sort: "capsules")

    assert_select "h1", "Registre des Privilégiés"
    assert_select ".register__tabs a[aria-current=true]", "Depuis toujours"
    assert_select ".register__sorts a[aria-current=true]", "Le plus de capsules"
    assert_select ".player-tile.player-tile--own", 1
    assert_select ".register__mine", /Votre chance/

    get fortune_register_path(locale: :en)

    assert_select ".register__empty", "No member has opened a capsule this week yet."
    assert_select ".register__mine", false
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
