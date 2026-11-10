require "test_helper"

class Game::Market::CreateFirstSettingsTest < ActiveSupport::TestCase
  setup { Game::Market::Settings.delete_all }

  test "the first version is closed and holds the starting values" do
    settings = Game::Market::CreateFirstSettings.new.call.value!

    assert_not settings.open
    assert_equal [ 1_000, 2_000, 5_000, 15_000, 100_000 ], %i[common uncommon rare epic legendary].map { settings.entrustment(it) }
    assert_equal 1_200_000, settings.daily_cap
    assert_equal 1_000, settings.commission_basis_points
    assert_nil settings.replaces_id
    assert settings.token.present?
  end

  test "running it twice leaves one version" do
    Game::Market::CreateFirstSettings.new.call.value!

    assert_no_difference -> { Game::Market::Settings.count } do
      assert Game::Market::CreateFirstSettings.new.call.success?
    end
  end

  test "it leaves a version that already exists alone, whatever its state" do
    existing = Game::Market::Settings.create!(Game::Market::StartingSettings::ATTRIBUTES.merge(open: true))

    assert_no_difference -> { Game::Market::Settings.count } do
      assert_equal existing, Game::Market::CreateFirstSettings.new.call.value!
    end
  end

  test "the current version is the highest id" do
    Game::Market::CreateFirstSettings.new.call.value!
    later = Game::Market::Settings.create!(Game::Market::StartingSettings::ATTRIBUTES.merge(open: true))

    assert_equal later, Game::Market::CurrentSettings.call
  end
end
