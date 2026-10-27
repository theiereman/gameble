require "test_helper"

class DomainsTest < ActiveSupport::TestCase
  test "the four domains are loaded" do
    names = Packs.all.map(&:name)

    assert_equal %w[app/domains/accounts app/domains/catalog app/domains/game app/domains/steam], names.sort
  end
end
