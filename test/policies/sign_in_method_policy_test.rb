require "test_helper"

class SignInMethodPolicyTest < ActiveSupport::TestCase
  test "a visitor may not add a sign-in" do
    assert_not SignInMethodPolicy.new(nil, :sign_in_method).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may add a sign-in" do
      assert SignInMethodPolicy.new(accounts_players(role), :sign_in_method).create?
    end
  end
end
