require "test_helper"
require_relative "../../support/game_packs"

# Replacement packs (R1, R4, AD-7): opening a regular pack tops the bank back
# up to ten, each new pack drawn at once and scheduled ten minutes after the
# later of the opening and the latest time in the bank; the bank summary's
# next pack; and the healing of banks left short (Game::HealBank,
# game:top_up_banks).
class Game::TopUpBankTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
    @now = Time.current.change(usec: 0)
  end

  def open = Game::OpenPack.new.call(player: @player)
  def bank = Game::Pack.bank(@player.id)
  def summary = Game::BankSummary.call(@player).except(:bonus_collectable)

  def full_bank_at(time)
    travel_to(time) { Game::FillBank.new.call(player: @player).value! }
  end

  test "opening a full bank draws a replacement at once, ten minutes after the opening" do
    full_bank_at(@now)

    travel_to(@now) do
      opened = open.value!
      assert_equal 10, bank.count
      replacement = bank.where.not(id: opened.id).order(:id).last
      assert_equal @now + 10.minutes, replacement.available_at
      assert_predicate replacement, :regular?
      assert_equal catalog_seasons(:one).id, replacement.season_id
      assert_equal 5, replacement.card_season_ids.size
      assert_empty replacement.card_season_ids - fixture_tier_ids
      assert_equal({ available: 9, next_available_at: @now + 10.minutes }, summary)
    end
  end

  test "with scheduled packs, the replacement comes ten minutes after the latest" do
    8.times { create_pack(@player, available_at: @now - 1.minute) }
    create_pack(@player, available_at: @now + 4.minutes)
    create_pack(@player, available_at: @now + 14.minutes)

    travel_to(@now) { open.value! }

    assert_equal 10, bank.count
    assert_equal @now + 24.minutes, bank.maximum(:available_at)
    assert_equal 1, bank.where(available_at: @now + 24.minutes).count
  end

  test "packs accrue while away: back 35 minutes after ten openings, three are there and the next comes at 40" do
    full_bank_at(@now)
    travel_to(@now) { 10.times { open.value! } }

    travel_to(@now + 35.minutes) do
      assert_equal 10, bank.count
      assert_equal({ available: 3, next_available_at: @now + 40.minutes }, summary)
      assert_equal 7, bank.where(available_at: (@now + 35.minutes)..).count
    end
  end

  test "over thirty openings at varied times the bank always holds ten, never more than ten available" do
    full_bank_at(@now)
    time = @now
    random = Random.new(42)

    30.times do
      time += random.rand(0..25).minutes
      travel_to(time) do
        open if summary[:available].positive?
        assert_equal 10, bank.count
        assert_operator bank.available(time).count, :<=, 10
        times = bank.order(:available_at).pluck(:available_at).select { |at| at > time }
        assert_equal times.uniq, times, "scheduled packs should never share a time"
      end
    end
    assert_operator Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).count, :>=, 20
  end

  test "a bank left short is topped up to ten, ten minutes apart from the later of now and its latest time" do
    create_pack(@player, available_at: @now - 2.minutes)
    create_pack(@player, available_at: @now - 1.minute)
    create_pack(@player, available_at: @now + 3.minutes)

    travel_to(@now) { open.value! }

    assert_equal 10, bank.count
    scheduled = bank.order(:available_at).pluck(:available_at).last(8)
    assert_equal (1..8).map { |step| @now + 3.minutes + (step * 10).minutes }, scheduled
  end

  test "with no published season the opening succeeds and nothing is inserted" do
    full_bank_at(@now)
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    travel_to(@now) { assert open.success? }

    assert_equal 9, bank.count
    assert_equal 10, Game::Pack.where(player_id: @player.id).count
  end

  test "opening a bonus pack tops nothing up; bonus packs never count in the bank nor show a next pack" do
    full_bank_at(@now - 1.minute)
    bonus = create_pack(@player, available_at: @now - 2.minutes, kind: :bonus)
    create_pack(@player, available_at: @now + 5.minutes, kind: :bonus)

    travel_to(@now) do
      assert_equal bonus, open.value!
      assert_equal 10, Game::Pack.where(player_id: @player.id).regular.count
      assert_equal({ available: 10, next_available_at: nil }, summary)
    end
  end

  test "the bank summary of a player without a bank has no next pack" do
    assert_equal({ available: 0, next_available_at: nil }, summary)
  end

  test "an emptied bank is healed with ten packs scheduled from now, once, and BankToppedUp" do
    create_pack(@player, opened_at: @now - 1.hour)

    travel_to(@now) do
      assert_equal 10, Game::HealBank.new.call(player: @player).value!
      assert_equal (1..10).map { |step| @now + (step * 10).minutes }, bank.order(:available_at).pluck(:available_at)
      assert_equal 0, Game::HealBank.new.call(player: @player).value!
    end
    events = game_events(@player, Game::BankToppedUp)
    assert_equal [ { player_id: @player.id, packs: 10 } ], events.map(&:data)
  end

  test "healing leaves alone a player who never had a pack, and a missing or banned player fails" do
    assert_equal 0, Game::HealBank.new.call(player: @player).value!
    assert_equal 0, Game::Pack.count
    [ nil, accounts_players(:banned) ].each do |player|
      assert_equal :player_required, Game::HealBank.new.call(player:).failure
    end
  end

  test "game:top_up_banks heals every emptied bank and adds nothing on a second run" do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "game:top_up_banks" }
    create_pack(@player, opened_at: @now - 1.hour)
    moderator = accounts_players(:moderator)
    Game::FillBank.new.call(player: moderator).value!

    run = -> { capture_io { Rake::Task["game:top_up_banks"].tap(&:reenable).invoke } }

    travel_to(@now) { run.call }
    assert_equal 10, bank.count
    assert_equal 10, Game::Pack.bank(moderator.id).count
    assert_no_difference -> { Game::Pack.count } do
      travel_to(@now) { run.call }
    end
  end
end
