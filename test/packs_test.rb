require "test_helper"

class PacksTest < ActiveSupport::TestCase
  test "the four domain packs are loaded" do
    names = Packs.all.map(&:name)

    assert_equal %w[app/domains/accounts packs/catalog packs/game packs/steam], names.sort
  end
end
