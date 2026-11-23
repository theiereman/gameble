require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/feed_reactions"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_listings"
require_relative "../support/market_orders"

class BellsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include FeedReactions
  include MarketAuctions
  include MarketListings
  include MarketOrders
  include MarketSettings

  FRAME = "turbo-frame#bell-items[target=_top]".freeze

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
  end

  def get_bell(locale: :en)
    get bell_path(locale:), headers: { "Turbo-Frame" => "bell-items" }
  end

  def trade(from, to)
    low, high = [ from.id, to.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: from.id, recipient_id: to.id,
      proposed_at: 1.hour.ago, expires_at: 1.day.from_now)
  end

  def line_keys = css_select("#{FRAME} li.bell__line[data-bell-target=item]").map { it["data-bell-key"] }

  test "the frame holds a line per thing new, each a link to its target, keyed without any id, writing nothing" do
    waiting = trade(@max, @hugo)
    invitation = Game::Invitation.create!(sender_id: @eve.id, recipient_id: @hugo.id, status: "pending")
    Game::WeeklyGoal.create!(week_start: Game::WeeklyGoal.week_start(Time.current), total: 0, target: 1_500)
    sign_in(@hugo)

    assert_no_difference -> { Game::Trade.count + Game::Invitation.count + Game::DailyBonusClaim.count } do
      get_bell
    end

    assert_response :success
    today = Time.current.utc.to_date.iso8601
    week = Game::WeeklyGoal.week_start(Time.current).iso8601
    assert_equal [ "trade:#{waiting.token}:#{waiting.revision}", "invitation:#{invitation.token}", "daily:#{today}", "mission:#{week}" ], line_keys

    assert_select "#{FRAME} li[data-bell-path='/en/trades/#{waiting.token}'] a.bell__link[href='/en/trades/#{waiting.token}'][data-action='bell#follow']",
      text: /#{@max.persona_name} awaits your answer to a trade\.\s+Answer/
    assert_select "#{FRAME} li[data-bell-path='/en/friends'] a[href='/en/friends']", text: /#{@eve.persona_name} invites you to be friends\.\s+See/
    assert_select "#{FRAME} li#bell-daily[data-bell-lasting=true][data-bell-path='/en/booster'] a[href='/en/booster']", text: /Your daily capsule is ready\.\s+Collect/
    assert_select "#{FRAME} li[data-bell-lasting=false]", 3
    assert_select "#{FRAME} li:not([data-bell-path]) a[href='/en#community-goal']",
      text: /This week's mission: open 1,500 capsules together\.\s+See/
    assert_select "#{FRAME} p.bell__empty[data-bell-target=empty][hidden]", "Nothing new for now."
  end

  test "an answered proposal is a line to its trade, keyed by token and closing time, in the request's locale" do
    low, high = [ @hugo.id, @max.id ].minmax
    answered = Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: @hugo.id, recipient_id: @max.id, status: "declined",
      proposed_at: 2.hours.ago, expires_at: 1.day.from_now, closed_at: 1.hour.ago)
    sign_in(@hugo)

    assert_no_difference -> { Game::TradeView.count } do
      get_bell
    end

    assert_includes line_keys, "trade-update:#{answered.token}:#{answered.closed_at.utc.iso8601(6)}"
    assert_select "#{FRAME} li[data-bell-path='/en/trades/#{answered.token}']", text: /#{@max.persona_name} declined your trade\./

    get_bell(locale: :fr)
    assert_select "#{FRAME} li[data-bell-path='/fr/trades/#{answered.token}']", text: /#{@max.persona_name} a refusé votre échange\./
  end

  test "an entry others reacted to is a line to the feed after the invitations, keyed by token and latest notice, in the request's locale" do
    invitation = Game::Invitation.create!(sender_id: @eve.id, recipient_id: @hugo.id, status: "pending")
    @max.update!(persona_name: "Max")
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart").value!
    react(@eve, entry, "wow").value!
    @eve.update!(visibility: "private")
    sign_in(@hugo)

    get_bell

    assert_equal [ "invitation:#{invitation.token}", "reaction:#{entry.token}:#{Game::ReactionNotice.where(feed_entry_id: entry.id).maximum(:created_at).utc.iso8601(6)}" ], line_keys.first(2)
    assert_select "#{FRAME} li:not([data-bell-path])[data-bell-lasting=false] a[href='/en/feed?entry=#{entry.token}#entry-#{entry.token}']",
      text: /Max and 1 other reacted to your post\.\s+Heart\s+1\s+Wow\s+1\s+Portal\s+See/
    assert_select "#{FRAME} li:not([data-bell-path]) .bell__reaction img[src*='heart']"

    get_bell(locale: :fr)
    assert_select "#{FRAME} li:not([data-bell-path])", text: /Max et 1 autre ont réagi à votre publication\.\s+Cœur\s+1\s+Wow\s+1\s+Portal/

    @max.update!(visibility: "private")
    get_bell
    assert_select "#{FRAME} li:not([data-bell-path])", text: /2 players reacted to your post\./
  end

  test "an unclaimed mission reward replaces the week's line, in the request's locale" do
    Game::GoalReward.create!(player_id: @hugo.id, week_start: Date.new(2026, 9, 28))
    sign_in(@hugo)

    get_bell(locale: :fr)

    assert_includes line_keys, "mission-reward:2026-09-28"
    assert_select "#{FRAME} li#bell-mission-reward[data-bell-lasting=true]"
    assert_select "#{FRAME} li:not([data-bell-path]) a[href='/fr#community-goal']",
      text: /La mission hebdo est accomplie ?\s?: une capsule rare vous attend\.\s+Récupérer/
  end

  test "once the week's mission is accomplished, its line says so" do
    Game::WeeklyGoal.create!(week_start: Game::WeeklyGoal.week_start(Time.current), total: 1_500, target: 1_500)
    sign_in(@hugo)

    get_bell

    assert_select "#{FRAME} li:not([data-bell-path])[data-bell-lasting=false] a",
      text: /This week's mission is accomplished: 1,500 capsules opened together\.\s+See/
  end

  test "a line read on any device is marked read, a lasting line never is" do
    invitation = Game::Invitation.create!(sender_id: @eve.id, recipient_id: @hugo.id, status: "pending")
    today = Time.current.utc.to_date.iso8601
    Game::MarkBellRead.new.call(player: @hugo, keys: [ "invitation:#{invitation.token}", "daily:#{today}" ])
    sign_in(@hugo)

    get_bell

    assert_select "#{FRAME} li[data-bell-key='invitation:#{invitation.token}'][data-bell-read=true]"
    assert_select "#{FRAME} li#bell-daily[data-bell-read=false]"
  end

  test "the market slot shows an order line to its Annonce, then one grouped wanted line, read once marked on any device" do
    open_market!
    fund!(@hugo, 10_000)
    rare = catalog_card_seasons(:rare_card_one)
    order = order!(@hugo, rare, 100)
    order!(@hugo, catalog_card_seasons(:common_card_one), 100)
    Game::Market::RebuildWanted.new.call(player: @hugo).value!
    above = listing!(seller: @max, card_season: rare, starting_price: 150)
    Game::Market::Notice.record(player_id: @hugo.id, listing_id: above.id, order_id: order.id, kind: "listed_above_order", other_player_id: @max.id,
      amount: 150, at: Time.utc(2026, 11, 10, 12))
    wanted = listing!(seller: @max, card_season: catalog_card_seasons(:common_card_one))
    Game::Market::Notice.record(player_id: @hugo.id, listing_id: wanted.id, kind: "wanted", amount: 13)
    sign_in(@hugo)

    get_bell

    grouped = "wanted:grouped:#{wanted.created_at.utc.iso8601(6)}"
    assert_equal [ "order:#{order.token}:2026-11-10T12:00:00.000000Z", grouped ], line_keys.grep(/\A(order|wanted):/)
    assert_select "#{FRAME} li a[href='/en/market/listings/#{above.token}']", text: /Blue Depths is on sale for .+, above your order\./
    assert_select "#{FRAME} li[data-bell-key='#{grouped}'][data-bell-read=false] a[href='/en/market?wanted=1']",
      text: /Tin Soldier, a card you want, is on sale\./

    Game::MarkBellRead.new.call(player: @hugo, keys: [ grouped ]).value!
    get_bell

    assert_select "#{FRAME} li[data-bell-key='#{grouped}'][data-bell-read=true]"
  end

  test "a visit outside a frame is sent home" do
    sign_in(@hugo)

    get bell_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
  end

  test "a visitor is refused" do
    get_bell

    assert_redirected_to home_path(locale: :en)
    assert_select FRAME, false
  end
end
