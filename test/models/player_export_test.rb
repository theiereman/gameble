require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/game_trades"

class PlayerExportTest < ActiveSupport::TestCase
  include GamePacks
  include GameTrades

  SECTIONS = %i[exportedAt profile collection showcase packs dailyBonusDays goalRewardWeeks weeklyContributions setTiers
    firstDiscoveries feedEntries achievements friends pendingInvitations trades reportsFiled reportsReceived
    moderationDecisions].freeze
  COUNTING_KEYS = %i[season quantity position openings count received sent].freeze

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @staff = accounts_players(:administrator)
    @player.update!(persona_name: "Léa")
    @friend.update!(persona_name: "Hugo")
    @staff.update!(persona_name: "Inès")
    @portal = catalog_card_seasons(:portal_one).id
    @common = catalog_card_seasons(:common_card_one).id
    @rare = catalog_card_seasons(:rare_card_one).id
    @now = Time.utc(2026, 10, 14, 9, 30)
  end

  def export(player = @player, locale: :fr)
    PlayerExport.new(player, locale:, now: @now)
  end

  def keys_and_values(value, key = nil, &block)
    case value
    when Hash then value.each { |inner_key, inner| keys_and_values(inner, inner_key, &block) }
    when Array then value.each { keys_and_values(it, key, &block) }
    else yield key, value
    end
  end

  def all_keys(value)
    case value
    when Hash then value.keys + value.values.flat_map { all_keys(it) }
    when Array then value.flat_map { all_keys(it) }
    else []
    end
  end

  def assert_no_database_id(hash)
    assert_empty all_keys(hash).grep(/id\z/i) - [ :steamId ]
    keys_and_values(hash) do |key, value|
      assert_includes COUNTING_KEYS, key, "#{key}: #{value} looks like a database id" if value.is_a?(Integer)
    end
  end

  def assert_names_nobody_else(hash, *others)
    json = hash.to_json
    others.each do |other|
      [ other.token, other.persona_name, other.steam_id, Game::FriendCodeOf.call(other) ].compact.each do |trace|
        assert_not_includes json, trace
      end
    end
  end

  test "a player's export holds every section, by slug, season and token; the friend and the trade partner stay out" do
    opened = create_pack(@player, cards: [ @portal, @portal, @common, @rare, @portal ], available_at: 2.minutes.ago)
    Game::OpenPack.new.call(player: @player).value!
    conclude_trade(@friend, @player, offer: { @rare => 1 }, request: { @common => 1 })
    Game::AchievementUnlock.record(@player.id, :first_booster, Time.utc(2026, 10, 7))
    Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id: @portal, position: 1)
    Game::ShowcaseEntry.create!(player_id: @player.id, card_season_id: @rare, position: 0)

    hash = export.to_h

    assert_equal SECTIONS, hash.keys
    assert_equal [ { slug: "blue-depths", season: 1, position: 0 }, { slug: "portal", season: 1, position: 1 } ], hash[:showcase]
    assert_equal "2026-10-14T09:30:00Z", hash[:exportedAt]
    assert_equal({ steamId: "76561197960287001", personaName: "Léa", visibility: "public", reducedMotion: nil,
      friendCode: "7K2Q-F3NX", createdAt: @player.created_at.utc.iso8601, lastSeenAt: nil, lastExportedAt: nil }, hash[:profile])
    portal = hash[:collection].find { it[:slug] == "portal" }
    assert_equal({ slug: "portal", season: 1, title: "Portal", quantity: 3 }, portal.except(:lastGainedAt))
    assert_includes hash[:collection].map { it[:title] }, "Profondeurs bleues"
    pack = hash[:packs].find { it[:token] == opened.token }
    assert_equal [ opened.token, "regular", 1, "standard" ], pack.values_at(:token, :kind, :season, :cardBack)
    assert_equal [ "portal", "portal", "tin-soldier", "blue-depths", "portal" ], pack[:cards].map { it[:slug] }
    assert_equal [ { week: Game::WeeklyGoal.week_start(Time.current.utc).iso8601, openings: 1 } ], hash[:weeklyContributions]
    assert_equal [ [ 1, "studio", "valve", "complete", "pack" ] ], hash[:setTiers].map { it.values_at(:season, :kind, :key, :tier, :reachedBy) }
    assert hash[:setTiers].sole[:reachedAt]
    assert_equal [ { achievement: "first_booster", unlockedAt: "2026-10-07T00:00:00Z" } ], hash[:achievements]
    trade_entry = hash[:feedEntries].find { it[:kind] == "trade" }
    assert_equal({ slug: "tin-soldier", season: 1 }, trade_entry[:card])
    set_entry = hash[:feedEntries].find { it[:kind] == "set" }
    assert_equal({ kind: "set", set: { season: 1, kind: "studio", key: "valve" }, tier: "complete", count: 1 }, set_entry.except(:occurredAt))
    assert set_entry[:occurredAt]
    assert_equal({ count: 1 }, hash[:friends])
    trade = hash[:trades].sole
    assert_equal [ "accepted", [ { slug: "tin-soldier", season: 1, quantity: 1 } ] ], trade.values_at(:status, :offered)
    assert_equal %i[status proposedAt closedAt offered], trade.keys
    assert_no_database_id(hash)
    assert_names_nobody_else(hash, @friend)
  end

  test "an empty player's export holds every section, empty" do
    hash = export.to_h

    assert_equal SECTIONS, hash.keys
    %i[collection showcase packs dailyBonusDays goalRewardWeeks weeklyContributions setTiers firstDiscoveries feedEntries
       achievements trades reportsFiled reportsReceived moderationDecisions].each { assert_equal [], hash[it], it }
    assert_equal({ count: 0 }, hash[:friends])
    assert_equal({ received: 0, sent: 0 }, hash[:pendingInvitations])
    assert_no_database_id(hash)
  end

  test "one player's export holds none of another's cards, packs, name, token or code" do
    theirs = create_pack(@friend, cards: Array.new(5, @rare), available_at: 2.minutes.ago)
    Game::OpenPack.new.call(player: @friend).value!
    create_pack(@player, cards: Array.new(5, @common), available_at: 2.minutes.ago)
    Game::OpenPack.new.call(player: @player).value!

    hash = export.to_h

    assert_equal [ "tin-soldier" ], hash[:collection].map { it[:slug] }
    assert_not_includes hash.to_json, theirs.token
    assert_not_includes hash.to_json, "blue-depths"
    assert_names_nobody_else(hash, @friend)
    assert_no_database_id(hash)
  end

  test "a moderated player sees the reports against them and the decisions, never the reporter or the staff member" do
    assert Accounts::ReportPlayer.new.call(reporter: @friend, reported: @player, reason: "inappropriate_name").success?
    assert Accounts::ReportPlayer.new.call(reporter: @player, reported: @friend, reason: "cheating").success?
    assert Accounts::BanPlayer.new.call(staff: @staff, player: @player, reason: "Offensive name").success?
    assert Accounts::UnbanPlayer.new.call(staff: @staff, player: @player.reload).success?

    hash = export(@player.reload).to_h

    received = hash[:reportsReceived].sole
    assert_equal "inappropriate_name", received[:reason]
    assert received[:createdAt]
    assert received[:handledAt]
    assert_equal [ "cheating" ], hash[:reportsFiled].map { it[:reason] }
    assert_equal [ [ "ban", "Offensive name" ], [ "unban", nil ] ], hash[:moderationDecisions].map { it.values_at(:kind, :reason) }
    assert hash[:moderationDecisions].all? { it[:createdAt] }
    assert_names_nobody_else(hash, @friend, @staff)
    assert_no_database_id(hash)
  end

  test "the file is named by the UTC day of the export" do
    assert_equal "gameble-export-2026-10-14.json", export.filename
    assert_equal "gameble-export-2026-10-15.json", PlayerExport.new(@player, locale: :en, now: Time.utc(2026, 10, 15, 0, 5)).filename
  end
end
