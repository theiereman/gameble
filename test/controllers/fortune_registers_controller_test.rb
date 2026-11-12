require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The Flukeometer, a dashboard of this week's ranked players, and
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

  def stranger(name)
    Accounts::Player.create!(steam_id: "76561197960400#{name.sum % 1000}", persona_name: name)
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  test "the week's board has one line per player: rank, name, Privileged badge and label, a count per rarity, capsules and the luck last" do
    open_cards(@player, 5)
    open_cards(@player, 1)
    sign_in(@player)

    get fortune_register_path(locale: :en)

    assert_response :success
    assert_select "h1", "The Flukeometer"
    assert_select ".register__mine-label", "Your luck · This week"
    assert_select ".register__mine-index.fortune-index--up", "+500"
    assert_select ".register__mine-rank .fortune__privileged", "PRIVILEGED"
    assert_select ".register__mine-rank", /#1 of 1/
    assert_select ".register__summary .register__figure", text: /Active this week\s*1/
    assert_select ".register__summary .register__figure", text: /Capsules this week\s*2/
    assert_select ".register__summary .register__figure", text: /Privileged of 1\s*1/
    assert_select ".fortune-gauge__column--privileged", minimum: 1
    assert_select ".fortune-gauge__zone-label", "PRIVILEGED"
    assert_select ".register__head", 1
    assert_select ".player-row", 1
    assert_select ".register__cut", false
    assert_select ".player-row:nth-child(1).player-row--privileged.player-row--own" do
      assert_select ".player-row__rank", "1"
      assert_select "button.player-row__name[aria-haspopup=dialog]", "Hugo"
      assert_select ".player-row__who .fortune__privileged", "PRIVILEGED"
      assert_select ".player-row__you", "YOU"
      assert_select ".player-row__label"
      assert_select ".player-row__capsules dt svg.player-row__icon"
      assert_select ".player-row__capsules dt .visually-hidden", "Capsules"
      assert_select ".player-row__capsules dd", "2"
      assert_select ".player-row__rarity svg.player-row__icon", 5
      assert_select ".player-row__figure:first-child.player-row__rarity--5"
      assert_select ".player-row__rarity--1 dd", "5"
      assert_select ".player-row__rarity--3 dd", "0"
      assert_select ".player-row__rarity--5 dd", "5"
      assert_select ".player-row__rarity--5 dt .visually-hidden", "Legendary"
      assert_select ":last-child.player-row__luck .player-row__index.fortune-index--up", "+500"
      assert_select ".player-row__luck .player-row__share-word", "Top"
      assert_select ".player-row__luck .player-row__share-value", "100%"
    end
    assert_select "dialog#player-card-#{@player.token} turbo-frame[src=?][loading=lazy]", brother_summary_path(locale: :en, token: @player.token)
    assert_select "dialog.modal", 1
    assert_select "[style]", false
  end

  test "a line marks the Privileged threshold on the week's luck order only" do
    open_cards(@player, 5)
    open_cards(stranger("Other"), 1)

    get fortune_register_path(locale: :en)

    assert_select ".register__rows > li", 3
    assert_select ".register__rows > li:nth-child(2).register__cut", "Privileged threshold · the luckiest 10%"

    get fortune_register_path(locale: :en, sort: "capsules")

    assert_select ".register__cut", false
  end

  test "a private player has no row and counts nowhere, and sees their own index without a rank" do
    @player.update!(visibility: :private)
    open_cards(@player, 5)
    open_cards(stranger("Other"), 1)
    sign_in(@player)

    get fortune_register_path(locale: :en)

    assert_select ".player-row", 1
    assert_select "button.player-row__name", "Other"
    assert_select ".player-row--own", false
    assert_select ".register__summary .register__figure", text: /Active this week\s*1/
    assert_select ".register__mine", false
    assert_no_match "Hugo", css_select(".register__rows").text

    get brother_path(locale: :en, token: @player.token)

    assert_select ".fortune-index__value", "+500"
    assert_select ".fortune__rank", false
    assert_select ".fortune__standing", false
    assert_select ".fortune__privileged", false
  end

  test "a friends-only player is named for a friend and stays an anonymous row for a stranger" do
    @player.update!(visibility: :friends_only)
    open_cards(@player, 1)
    friend = stranger("Friend")
    befriend(friend, @player)

    get fortune_register_path(locale: :en)

    assert_select ".player-row__name--hidden", "Private member"
    assert_select ".player-row__rarity dd", text: "–", count: 5
    assert_select "dialog.modal", false

    sign_in(friend)
    get fortune_register_path(locale: :en)

    assert_select "button.player-row__name", "Hugo"
    assert_select "dialog#player-card-#{@player.token}"
  end

  test "the leaderboard answers a browser too old for the game" do
    get fortune_register_path(locale: :en), headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 6.1; rv:40.0) Gecko/20100101 Firefox/40.0" }

    assert_response :success
  end

  test "a period tab renders the Fortune frame alone" do
    open_cards(@player, 1)

    get brother_path(locale: :en, token: @player.token, fortune: "all_time"), headers: { "Turbo-Frame" => "profile-fortune" }

    assert_response :success
    assert_select "turbo-frame", 1
    assert_select "turbo-frame#profile-fortune .fortune__tabs a[aria-current=true]", "All time"
    assert_select "h1", false
  end

  test "the order by capsules in French, with no period to pick" do
    open_cards(@player, 3)
    sign_in(@player)

    get fortune_register_path(locale: :fr, sort: "capsules")

    assert_select "h1", "Le Chattomètre"
    assert_select ".register__controls nav", 1
    assert_select ".register__sorts a[aria-current=true]", "Le plus de capsules"
    assert_select ".register__sorts a[href=?]", fortune_register_path(locale: :fr), "Les plus chanceux"
    assert_select ".player-row.player-row--own", 1
    assert_select ".register__mine-label", "Votre chance · Cette semaine"
    assert_select ".register__summary .register__figure", text: /Actifs cette semaine\s*1/
  end

  test "a week without any capsule is empty, whatever an old link asks for" do
    travel_to(2.weeks.ago) { open_cards(@player, 3) }
    travel_to(1.week.ago) { open_cards(@player, 3) }
    sign_in(@player)

    %w[last_week all_time].each do |period|
      get fortune_register_path(locale: :en, period:)

      assert_response :success
      assert_select ".register__empty", "No member has opened a capsule this week yet."
      assert_select ".register__mine", false
    end
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
      assert_select ".player-card__more a.button--link[href=?]", brother_path(locale: :en, token: @player.token)
    end
  end

  test "a hidden player's card is the unavailable page" do
    @player.update!(visibility: :private)

    get brother_summary_path(locale: :en, token: @player.token)

    assert_response :not_found
  end

  test "a profile has no last-week tab" do
    travel_to(1.week.ago) { open_cards(@player, 3) }

    get brother_path(locale: :en, token: @player.token, fortune: "last_week")

    assert_select ".fortune__tabs a", 2
    assert_select ".fortune__tabs a[aria-current=true]", "This week"
  end

  test "the gauge heads the register: a marker for a ranked player, none for a visitor, and the way back leads to the bridge" do
    open_cards(@player, 3)

    get fortune_register_path(locale: :en)

    assert_select ".register__gauge .fortune-gauge__column", 49
    assert_select ".fortune-gauge__marker", false

    sign_in(@player)
    get fortune_register_path(locale: :en)

    assert_select ".register__gauge .fortune-gauge__marker", 1
    assert_select ".top-bar__phone-back[href=?]", home_path(locale: :en)
  end

  test "a profile's all-time tab, and a period without any pack" do
    travel_to(2.weeks.ago) { open_cards(@player, 1) }

    get brother_path(locale: :en, token: @player.token, fortune: "all_time")
    assert_select ".fortune__tabs a[aria-current=true]", "All time"
    assert_select ".fortune-index__value", /\A-\d+\z/
    assert_select ".fortune__privileged", false
    assert_select ".fortune__rank", "Rank 1 of 1"
    assert_select ".fortune__rank a", false

    get brother_path(locale: :en, token: @player.token)
    assert_select ".fortune__empty", "No capsule opened this week yet."
  end
end
