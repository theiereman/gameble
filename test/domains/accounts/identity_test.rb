require "test_helper"

class Accounts::IdentityTest < ActiveSupport::TestCase
  def build(**attributes)
    Accounts::Identity.new({ player: accounts_players(:player), provider: "discord", uid: "42" }.merge(attributes))
  end

  test "a provider uid pair belongs to one identity" do
    build.save!
    assert_raises(ActiveRecord::RecordNotUnique) do
      Accounts::Identity.transaction(requires_new: true) { build(player: accounts_players(:moderator)).save! }
    end
    assert build(provider: "google").valid?
  end

  test "a player without a steam id is valid, a malformed one is not" do
    assert Accounts::Player.new(steam_id: nil, persona_name: "Brother-AAAAAA").valid?
    assert_not Accounts::Player.new(steam_id: "123").valid?
  end
end
