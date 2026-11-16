require "test_helper"

class ExternalLinkOpenPolicyTest < ActiveSupport::TestCase
  test "a visitor may not record a link opened" do
    assert_not ExternalLinkOpenPolicy.new(nil, :external_link_open).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may" do
      assert ExternalLinkOpenPolicy.new(accounts_players(role), :external_link_open).create?
    end
  end
end
