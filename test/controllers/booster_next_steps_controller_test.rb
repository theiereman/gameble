require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# What the capsule screen proposes once the reserve is empty: inline when the
# screen opens on it, otherwise in a frame the booster loads when it runs out.
class BoosterNextStepsControllerTest < ActionDispatch::IntegrationTest
  include CustomSets
  include GamePacks
  include GameSets
  include Holdings
  include SteamSignIn

  PANEL = "section#booster.booster section.booster-next-steps[data-controller=booster-next-steps]".freeze
  FRAME = "turbo-frame#booster-next-steps-frame[target=_top]".freeze

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
  end

  # A set two cards from bronze, a goal whose card the friend spares, and a reward to claim.
  def give_hooks
    members = unheld_cards(6)
    @set = Catalog::Set.find(insert_set(members, { bronze: 4, complete: 6 }, key: "roguelike"))
    hold_all(@player, members.first(2))
    @friend.update!(persona_name: "Léa")
    low, high = [ @player.id, @friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    wanted = catalog_card_seasons(:portal_one)
    card_ids = Catalog::CardSeason.where(id: [ wanted.id, *unheld_cards(2) ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @player, custom_set: create_custom_set(@player, name: "Favourites", card_ids:).token).value!
    hold(@friend, wanted.id, 2)
    Game::AchievementUnlock.record(@player.id, "boosters_100", Time.current, claimed: false)
  end

  def links
    css_select("#{PANEL} .booster-next-steps__link").map { [ it["href"], it.at_css(".booster-next-steps__name").text, it.at_css(".booster-next-steps__hook")&.text ] }
  end

  def get_frame
    get booster_next_steps_path(locale: :en), headers: { "Turbo-Frame" => "booster-next-steps-frame" }
  end

  test "an empty reserve shows the three proposals inline, each with its hook" do
    give_hooks
    sign_in(@player)

    get booster_path(locale: :en)

    assert_response :success
    assert_select "#{PANEL}:not([hidden])[data-booster-next-steps-url-value='/en/booster/next-steps']" do
      assert_select "h2#booster-next-steps-title", "What next?"
      assert_select FRAME
    end
    assert_equal "#booster [data-controller~='booster-next-steps']", css_select("section#booster").sole["data-booster-booster-next-steps-outlet"]
    assert_equal [ [ "/en/library", "Your sets", "#{SetLabel.for(@set)} · 2 more for Bronze" ],
                   [ "/en/friends", "Your friends", "Léa has a card one of your goals needs" ],
                   [ "/en/me", "Your profile", "1 reward to claim" ] ], links
    assert_select "#{PANEL} .booster-next-steps__daily", 0
    assert_select "[style]", 0
  end

  test "with no set in progress, no goal and no reward, the proposals show without hooks" do
    sign_in(@player)

    get booster_path(locale: :en)

    assert_equal [ [ "/en/library", "Your sets", nil ], [ "/en/friends", "Your friends", nil ], [ "/en/me", "Your profile", nil ] ], links
  end

  test "once today's daily capsule is collected, the panel says when the next one comes" do
    now = Time.utc(2026, 10, 6, 14, 22)
    bonus = create_pack(@player, kind: :bonus, opened_at: now - 1.minute)
    Game::DailyBonusClaim.create!(player_id: @player.id, day: Game::DailyBonusClaim.day_of(now), pack_id: bonus.id)
    sign_in(@player)

    travel_to(now) { get booster_path(locale: :en) }

    assert_select "#{PANEL} .booster-next-steps__daily", /\ANext daily capsule: / do
      assert_select "time[datetime='2026-10-07T00:00:00Z']"
    end
  end

  test "with a capsule left, the panel is hidden, its frame empty and no hook read" do
    give_hooks
    create_pack(@player)
    sign_in(@player)
    queries = []
    record = ->(*, payload) { queries << "#{payload[:name]} #{payload[:sql]}" }

    ActiveSupport::Notifications.subscribed(record, "sql.active_record") { get booster_path(locale: :en) }

    assert_response :success
    assert_select "#{PANEL}[hidden]" do
      assert_select "#{FRAME} *", 0
    end
    assert_empty queries.grep(/json_object_agg\(tiers\.tier|Game::TradeSuggestions|game_goals/)
  end

  test "the frame brings the proposals with their hooks" do
    give_hooks
    sign_in(@player)

    get_frame

    assert_response :success
    assert_select FRAME do
      assert_select ".booster-next-steps__link", 3
      assert_select ".booster-next-steps__hook", 3
    end
  end

  test "the frame asked outside a frame leads to the capsule screen" do
    sign_in(@player)

    get booster_next_steps_path(locale: :en)

    assert_redirected_to booster_path(locale: :en)
  end

  test "a visitor asking for the frame is sent to the landing, as on the capsule screen" do
    get_frame

    assert_redirected_to home_path(locale: :en)
  end
end
