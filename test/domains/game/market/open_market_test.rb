require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/singleton_stub"

class Game::Market::OpenMarketTest < ActiveSupport::TestCase
  include MarketSettings
  include SingletonStub

  setup do
    Game::Market::Settings.delete_all
    @administrator = accounts_players(:administrator)
    @closed = close_market!
  end

  def open_market(player: @administrator, terms: true, odds: true, fr: "Le marché ouvre", en: "The market opens")
    Game::Market::OpenMarket.new.call(player:, terms_confirmed: terms, odds_confirmed: odds, message_fr: fr, message_en: en)
  end

  def nothing_is_written(&)
    assert_no_difference([ -> { Game::Market::Settings.count }, -> { Accounts::Announcement.count } ], &)
  end

  test "the first opening inserts an open version, records the confirmations and the first opening, and shows the announcement" do
    previous = Accounts::CreateAnnouncement.new.call(staff: @administrator, message_fr: "Avant", message_en: "Before", shown: true).value!

    settings = open_market.value!

    assert settings.open
    assert_equal settings, Game::Market::CurrentSettings.call
    assert_equal @closed.id, settings.replaces_id
    assert_equal @administrator.id, settings.author_id
    assert settings.terms_confirmed_at && settings.odds_confirmed_at && settings.first_opened_at
    assert_equal @closed.daily_cap, settings.daily_cap
    assert_equal [ "The market opens" ], Accounts::Announcement.where(shown: true).pluck(:message_en)
    assert_not previous.reload.shown
  end

  test "it publishes one SettingsChanged event" do
    settings = open_market.value!

    events = Rails.configuration.event_store.read.stream(Game::Market::SettingsChanged::STREAM).of_type(Game::Market::SettingsChanged).to_a
    assert_includes events.map { it.data[:settings_id] }, settings.id
  end

  test "a reopening records the confirmations again and keeps the first opening time" do
    first = open_market.value!
    close_market!(first_opened_at: first.first_opened_at)

    reopened = open_market.value!

    assert reopened.open
    assert_equal first.first_opened_at, reopened.first_opened_at
    assert_not_nil reopened.terms_confirmed_at
  end

  test "an open market is not opened again" do
    open_market!

    nothing_is_written { assert_equal :market_already_open, open_market.failure }
  end

  test "each confirmation is required, terms first" do
    nothing_is_written do
      assert_equal :terms_not_confirmed, open_market(terms: false).failure
      assert_equal :odds_not_confirmed, open_market(odds: false).failure
      assert_equal :terms_not_confirmed, open_market(terms: false, odds: false).failure
      assert_equal :terms_not_confirmed, open_market(terms: "1").failure
    end
  end

  test "an announcement in a language that is empty or too long rolls the version back" do
    nothing_is_written do
      assert_equal :invalid_announcement, open_market(fr: " ").failure
      assert_equal :invalid_announcement, open_market(en: "x" * (Accounts::Announcement::MESSAGE_LENGTH + 1)).failure
    end
  end

  test "only an administrator opens the market" do
    nothing_is_written do
      [ accounts_players(:moderator), accounts_players(:player), accounts_players(:banned), nil ].each do |player|
        assert_equal :administrator_required, open_market(player:).failure
      end
    end
  end

  test "a version inserted first is a lost race" do
    stub_singleton(Game::Market::CurrentSettings, :call, -> { Game::Market::Settings.find(@closed.id) }) do
      close_market!(replaces_id: @closed.id)
      nothing_is_written { assert_equal :settings_changed, open_market.failure }
    end
  end

  test "a deadlock rolls back as market_busy" do
    stub_singleton(Game::Market::CurrentSettings, :call, -> { raise ActiveRecord::Deadlocked }) do
      nothing_is_written { assert_equal :market_busy, open_market.failure }
    end
  end

  test "reopening after a closing keeps the first opening time and records both confirmations again" do
    Game::Market::Settings.delete_all
    first = open_market.value!
    closed = Game::Market::ChangeSettings.new.call(player: @administrator, settings_token: first.token, close: true,
      message_fr: "Fermé", message_en: "Closed").value!

    reopened = travel(1.day) { open_market.value! }

    assert reopened.open
    assert_equal closed.id, reopened.replaces_id
    assert_equal first.first_opened_at, reopened.first_opened_at
    assert_operator reopened.terms_confirmed_at, :>, first.terms_confirmed_at
    assert_operator reopened.odds_confirmed_at, :>, first.odds_confirmed_at
  end
end
