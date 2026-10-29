require "test_helper"

class Accounts::EmailNormaliserTest < ActiveSupport::TestCase
  def normalise(address) = Accounts::EmailNormaliser.call(address)

  test "an address is lower-cased and trimmed" do
    assert_equal "gabe@example.com", normalise("  Gabe@Example.COM ")
  end

  test "a plus tag is removed" do
    assert_equal "gabe@example.com", normalise("gabe+games@example.com")
  end

  test "dots are removed for Gmail only" do
    assert_equal "gabenewell@gmail.com", normalise("Gabe.Newell+x@gmail.com")
    assert_equal "gabenewell@gmail.com", normalise("gabe.newell@googlemail.com")
    assert_equal "gabe.newell@example.com", normalise("gabe.newell@example.com")
  end

  test "a tag with no name before it keeps the address distinct" do
    assert_not_equal normalise("+a@example.com"), normalise("+b@example.com")
  end

  test "text without an at sign is only lower-cased" do
    assert_equal "nothing", normalise("Nothing")
    assert_equal "", normalise(nil)
  end
end
