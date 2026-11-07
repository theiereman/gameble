require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The Flukeometer, a dashboard of every ranked player, and
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

  test "the week's dashboard has one row per player: Privileged in place of the label, capsules, a count per rarity and the luck last" do
    hidden = Accounts::Player.create!(steam_id: "76561197960400101", persona_name: "Secret", visibility: :private)
    open_cards(@player, 5)
    open_cards(@player, 1)
    open_cards(hidden, 1)

    get fortune_register_path(locale: :en)

    assert_response :success
    assert_select "h1", "The Flukeometer"
    assert_select ".register__summary .profile-figure", text: /Active this week\s*2/
    assert_select ".register__summary .profile-figure", text: /Capsules this week\s*3/
    assert_select ".register__summary .profile-figure", text: %r{Privileged\s*1/2}
    assert_select ".player-row", 2
    assert_select ".player-row:nth-child(1).player-row--privileged" do
      assert_select "button.player-row__name[aria-haspopup=dialog]", "Hugo"
      assert_select ".player-row__who .fortune__privileged", "PRIVILEGED"
      assert_select ".player-row__label", false
      assert_select ".player-row__capsules dt svg.player-row__icon"
      assert_select ".player-row__capsules dt .visually-hidden", "Capsules"
      assert_select ".player-row__capsules dd", "2"
      assert_select ".player-row__rarity svg.player-row__icon", 5
      assert_select ".player-row__figure:first-child.player-row__rarity--5"
      assert_select ".player-row__figure:last-child.player-row__capsules"
      assert_select ".player-row__rarity--1 dd", "1"
      assert_select ".player-row__rarity--5 dd", "1"
      assert_select ".player-row__rarity--5 dt .visually-hidden", "Legendary"
      assert_select ":last-child.player-row__luck.fortune-index--up[title=?]", "+500"
      assert_select ".player-row__luck .player-row__share-word", "Top"
      assert_select ".player-row__luck .player-row__share-value", "50%"
    end
    assert_select ".player-row:nth-child(2)" do
      assert_select ".player-row__name--hidden", "Private member"
      assert_select ".fortune__privileged", false
      assert_select ".player-row__label"
      assert_select ".player-row__rarity dd", text: "–", count: 5
    end
    assert_select "dialog#player-card-#{@player.token} turbo-frame[src=?][loading=lazy]", brother_summary_path(locale: :en, token: @player.token)
    assert_select "dialog.modal", 1
    assert_no_match "Secret", response.body
    assert_select "[style]", false
  end

  test "the order by capsules, the all-time tab in French, and an empty week" do
    travel_to(2.weeks.ago) { open_cards(@player, 3) }
    sign_in(@player)

    get fortune_register_path(locale: :fr, period: "all_time", sort: "capsules")

    assert_select "h1", "Le Chattomètre"
    assert_select ".register__tabs a[aria-current=true]", "Depuis toujours"
    assert_select ".register__sorts a[aria-current=true]", "Le plus de capsules"
    assert_select ".player-row.player-row--own", 1
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
      assert_select ".fortune__label", /RNG's Favourite/
      assert_select ".fortune__privileged", "PRIVILEGED"
      assert_select ".fortune__rank a[href=?]", fortune_register_path(locale: :en), "Rank 1 of 1"
      assert_select ".profile-figure", text: /Points earned\s*500/
      assert_select ".profile-figure--rarity-5 .profile-figure__value", "5"
      assert_select ".fortune__standing", /Top\s*100%/
      assert_select ".fortune-odds h3", "Behind the luck"
      assert_select ".fortune-odds tbody tr", 3
      assert_select ".fortune-odds tfoot td:first-of-type", "1"
      assert_select ".fortune-odds__formula", /\A\s*Luck score: \(500 earned − [\d.]+ expected\) ÷ √[\d.]+ = [\d.]+\s*\z/
    end
  end

  test "a player's card for the dialog: name, Add friend for a stranger, the week's share and rarities, then a link to the full profile" do
    open_cards(@player, 5)
    sign_in(Accounts::Player.create!(steam_id: "76561197960400102", persona_name: "Stranger"))

    get brother_summary_path(locale: :en, token: @player.token)

    assert_response :success
    assert_select "turbo-frame#player-card-frame-#{@player.token}[target=_top] .player-card" do
      assert_select "h2", "Hugo"
      assert_select "[aria-label=?]", "#{I18n.t("public_profiles.show.add_friend_label", name: "Hugo")}", text: "ADD FRIEND"
      assert_select ".player-card__share", /Top\s*100%/
      assert_select ".player-card__label", /This week · RNG's Favourite/
      assert_select ".player-card__rarity:first-child.player-row__rarity--5 dd", "1"
      assert_select "a.player-card__more[href=?]", brother_path(locale: :en, token: @player.token)
    end
  end

  test "a hidden player's card is the unavailable page" do
    @player.update!(visibility: :private)

    get brother_summary_path(locale: :en, token: @player.token)

    assert_response :not_found
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
