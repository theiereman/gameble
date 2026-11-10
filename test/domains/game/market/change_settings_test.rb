require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/singleton_stub"

class Game::Market::ChangeSettingsTest < ActiveSupport::TestCase
  include MarketSettings
  include SingletonStub

  setup do
    Game::Market::Settings.delete_all
    @administrator = accounts_players(:administrator)
    @current = open_market!(first_opened_at: 3.days.ago, terms_confirmed_at: 3.days.ago, odds_confirmed_at: 3.days.ago)
  end

  def candidate(**changes)
    Game::Market::SettingsRules::EDITABLE.index_with { @current.public_send(it) }.merge(changes)
  end

  def change(player: @administrator, token: @current.token, fr: "Les réglages changent", en: "The settings change", **changes)
    Game::Market::ChangeSettings.new.call(player:, settings_token: token, candidate: candidate(**changes), message_fr: fr, message_en: en)
  end

  def nothing_is_written(&)
    assert_no_difference([ -> { Game::Market::Settings.count }, -> { Accounts::Announcement.count } ], &)
  end

  test "a valid change inserts the next version, records the author and shows the announcement" do
    settings = change(stamp_rare: 2_500, minimum_price_rare: 8_400).value!

    assert_equal settings, Game::Market::CurrentSettings.call
    assert_equal 2_500, settings.stamp_rare
    assert_equal 8_400, settings.minimum_price_rare
    assert_equal @current.id, settings.replaces_id
    assert_equal @administrator.id, settings.author_id
    assert_equal [ "The settings change" ], Accounts::Announcement.where(shown: true).pluck(:message_en)
  end

  test "the open state, both confirmations and the first opening are copied across" do
    settings = change(daily_cap: 1_300_000).value!

    assert settings.open
    assert_equal @current.first_opened_at, settings.first_opened_at
    assert_equal @current.terms_confirmed_at, settings.terms_confirmed_at
    assert_equal @current.odds_confirmed_at, settings.odds_confirmed_at
  end

  test "a closed market stays closed" do
    @current = close_market!(first_opened_at: 3.days.ago)

    assert_not change(daily_cap: 1_300_000).value!.open
  end

  test "it publishes one SettingsChanged event" do
    settings = change(daily_cap: 1_300_000).value!

    events = Rails.configuration.event_store.read.stream(Game::Market::SettingsChanged::STREAM).of_type(Game::Market::SettingsChanged).to_a
    assert_equal 1, events.count { it.data[:settings_id] == settings.id }
  end

  test "optional fields left blank are stored null" do
    settings = change(alert_destroyed_share_basis_points: nil, alert_picoins_per_player: nil, income_days_target_rare: nil).value!

    assert_nil settings.alert_destroyed_share_basis_points
    assert_nil settings.alert_picoins_per_player
    assert_nil settings.income_days_target_rare
  end

  test "values outside the candidate's editable columns are dropped" do
    candidate = candidate(daily_cap: 1_300_000).merge(open: false, first_opened_at: nil, author_id: 0, replaces_id: 0, token: "forged")

    settings = Game::Market::ChangeSettings.new.call(player: @administrator, settings_token: @current.token, candidate:, message_fr: "a", message_en: "b").value!

    assert settings.open
    assert_equal @current.first_opened_at, settings.first_opened_at
    assert_equal @administrator.id, settings.author_id
    assert_equal @current.id, settings.replaces_id
    assert_not_equal "forged", settings.token
  end

  test "a violation writes nothing and fails invalid_settings" do
    nothing_is_written do
      assert_equal :invalid_settings, change(minimum_price_rare: 7_700).failure
      assert_equal :invalid_settings, change(entrustment_rare: 10_001).failure
      assert_equal :invalid_settings, change(soft_close_seconds: "abc").failure
    end
  end

  test "a stale token fails settings_changed" do
    older_token = @current.token
    open_market!

    nothing_is_written { assert_equal :settings_changed, change(token: older_token).failure }
  end

  test "a blank token fails settings_changed" do
    nothing_is_written do
      assert_equal :settings_changed, change(token: nil).failure
      assert_equal :settings_changed, change(token: "").failure
    end
  end

  test "no version at all fails settings_changed" do
    Game::Market::Settings.delete_all

    nothing_is_written { assert_equal :settings_changed, change.failure }
  end

  test "a version inserted between the draw and the save is a lost race" do
    stale = @current
    stub_singleton(Game::Market::CurrentSettings, :call, -> { Game::Market::Settings.find(stale.id) }) do
      stale.successor(author: @administrator).save!
      nothing_is_written { assert_equal :settings_changed, change.failure }
    end
  end

  test "an announcement empty or too long rolls the whole change back" do
    nothing_is_written do
      assert_equal :invalid_announcement, change(fr: " ").failure
      assert_equal :invalid_announcement, change(en: "x" * (Accounts::Announcement::MESSAGE_LENGTH + 1)).failure
    end
  end

  test "only an administrator changes the settings" do
    nothing_is_written do
      [ accounts_players(:moderator), accounts_players(:player), accounts_players(:banned), nil ].each do |player|
        assert_equal :administrator_required, change(player:).failure
      end
    end
  end

  test "a deadlock rolls back as market_busy" do
    stub_singleton(Game::Market::CurrentSettings, :call, -> { raise ActiveRecord::Deadlocked }) do
      nothing_is_written { assert_equal :market_busy, change.failure }
    end
  end

  def close(player: @administrator, token: @current.token, fr: "Le marché ferme", en: "The market closes")
    Game::Market::ChangeSettings.new.call(player:, settings_token: token, message_fr: fr, message_en: en, close: true)
  end

  test "closing inserts a closed version carrying every value, both confirmation times and the first opening" do
    settings = close.value!

    assert_not settings.open
    assert_equal settings, Game::Market::CurrentSettings.call
    assert_equal @current.id, settings.replaces_id
    assert_equal @administrator.id, settings.author_id
    assert_equal @current.first_opened_at, settings.first_opened_at
    assert_equal @current.terms_confirmed_at, settings.terms_confirmed_at
    assert_equal @current.odds_confirmed_at, settings.odds_confirmed_at
    assert_equal @current.daily_cap, settings.daily_cap
  end

  test "closing shows its announcement in place of the previous one" do
    previous = Accounts::CreateAnnouncement.new.call(staff: @administrator, message_fr: "Avant", message_en: "Before", shown: true).value!

    close

    assert_equal [ "The market closes" ], Accounts::Announcement.where(shown: true).pluck(:message_en)
    assert_not previous.reload.shown
  end

  test "closing publishes one SettingsChanged event" do
    settings = close.value!

    events = Rails.configuration.event_store.read.stream(Game::Market::SettingsChanged::STREAM).of_type(Game::Market::SettingsChanged).to_a
    assert_equal 1, events.count { it.data[:settings_id] == settings.id }
  end

  test "closing a closed market fails market_already_closed" do
    @current = close_market!(first_opened_at: 3.days.ago)

    nothing_is_written { assert_equal :market_already_closed, close.failure }
  end

  test "closing without any version fails settings_changed" do
    Game::Market::Settings.delete_all

    nothing_is_written { assert_equal :settings_changed, close(token: "anything").failure }
  end

  test "closing with a stale or blank token fails settings_changed" do
    stale = @current
    change(daily_cap: 1_300_000)

    nothing_is_written do
      assert_equal :settings_changed, close(token: stale.token).failure
      assert_equal :settings_changed, close(token: "").failure
      assert_equal :settings_changed, close(token: nil).failure
    end
  end

  test "closing with an empty or too long announcement rolls the version back" do
    nothing_is_written do
      assert_equal :invalid_announcement, close(fr: " ").failure
      assert_equal :invalid_announcement, close(en: "x" * (Accounts::Announcement::MESSAGE_LENGTH + 1)).failure
    end
    assert Game::Market::CurrentSettings.call.open
  end

  test "only an administrator closes the market" do
    nothing_is_written do
      [ accounts_players(:moderator), accounts_players(:player), accounts_players(:banned), nil ].each do |player|
        assert_equal :administrator_required, close(player:).failure
      end
    end
  end

  test "a lost insert race on closing is settings_changed" do
    stale = @current
    stub_singleton(Game::Market::CurrentSettings, :call, -> { Game::Market::Settings.find(stale.id) }) do
      stale.successor(author: @administrator).save!
      nothing_is_written { assert_equal :settings_changed, close.failure }
    end
  end

  test "a deadlock while closing rolls back as market_busy" do
    stub_singleton(Game::Market::CurrentSettings, :call, -> { raise ActiveRecord::Deadlocked }) do
      nothing_is_written { assert_equal :market_busy, close.failure }
    end
  end
end
