require "test_helper"

class Accounts::HandleGeneratorTest < ActiveSupport::TestCase
  test "a handle is a word, a dash and six characters" do
    assert_match(/\A[A-Z][a-z]+-[A-HJ-NP-Z2-9]{6}\z/, Accounts::HandleGenerator.call)
  end

  test "a handle held by a player is drawn again" do
    answers = [ true, false ]
    calls = 0
    original = Accounts::Player.method(:exists?)
    Accounts::Player.define_singleton_method(:exists?) { |*| calls += 1; answers.shift }
    begin
      Accounts::HandleGenerator.call
    ensure
      Accounts::Player.define_singleton_method(:exists?, original)
    end
    assert_equal 2, calls
  end

  test "two handles differ" do
    assert_not_equal Accounts::HandleGenerator.call, Accounts::HandleGenerator.call
  end
end
