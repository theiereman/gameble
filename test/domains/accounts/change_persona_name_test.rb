require "test_helper"

class Accounts::ChangePersonaNameTest < ActiveSupport::TestCase
  setup do
    @player = Accounts::Player.create!(persona_name: "Brother-AAAAAA", welcome_pending: false)
    @player.identities.create!(provider: "discord", uid: "d-1")
  end

  def change(name, player: @player) = Accounts::ChangePersonaName.new.call(player:, name:)

  test "it stores the cleaned name and publishes an event without the name" do
    assert_equal @player, change("  Gabe   the  Brave ").value!
    assert_equal "Gabe the Brave", @player.reload.persona_name
    event = Rails.configuration.event_store.read.of_type(Accounts::PersonaNameChanged).to_a.sole
    assert_equal({ player_id: @player.id }, event.data)
  end

  test "the same name publishes nothing" do
    change("Gabe")
    assert_no_difference -> { Rails.configuration.event_store.read.of_type(Accounts::PersonaNameChanged).count } do
      assert change("Gabe").success?
    end
  end

  [ nil, "", "   ", "​​", 12 ].each do |name|
    test "#{name.inspect} is refused and changes nothing" do
      assert_equal Dry::Monads::Failure(:invalid_name), change(name)
      assert_equal "Brother-AAAAAA", @player.reload.persona_name
    end
  end

  test "a player with a Steam identity keeps the name Steam gives" do
    steam = accounts_players(:player)

    assert_equal Dry::Monads::Failure(:name_from_steam), change("Other", player: steam)
    assert_not_equal "Other", steam.reload.persona_name
  end

  test "no player, an unsaved one and a banned one are refused" do
    [ nil, Accounts::Player.new, accounts_players(:banned) ].each do |player|
      assert_equal Dry::Monads::Failure(:player_required), change("Gabe", player:)
    end
  end

  test "a failure has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { %i[invalid_name name_from_steam].each { assert_predicate Accounts::ChangePersonaName.failure_message(it), :present? } }
    end
  end
end
