require "test_helper"

# Catalog::StudioKeys: the studio of each card, as studio sets name it.
class Catalog::StudioKeysTest < ActiveSupport::TestCase
  def card(slug, developers)
    Catalog::Card.create!(source_key: "src:#{slug}", slug:, release_date: Date.new(2020, 1, 1), developers:,
      image_url: "https://images.example.test/#{slug}.jpg", store_url: "https://store.example.test/#{slug}")
  end

  test "developer names differing only in the forms studio sets merge share a key" do
    cards = [ "Valve", "Valve Corporation", "VALVE, Inc.", "Valve™" ].each_with_index.map { |name, index| card("studio-key-#{index}", [ name ]) }

    assert_equal 1, Catalog::StudioKeys.call(cards.map(&:id)).values.uniq.size
  end

  test "only the first developer counts, and a card without a usable developer has no studio" do
    first = card("studio-first", [ "Acme", "Valve" ])
    other = card("studio-second", [ "Valve", "Acme" ])
    none = card("studio-none", [])
    blank = card("studio-blank", [ "™" ])

    keys = Catalog::StudioKeys.call([ first, other, none, blank ].map(&:id))

    assert_equal [ first.id, other.id ].sort, keys.keys.sort
    assert_not_equal keys[first.id], keys[other.id]
    assert_empty Catalog::StudioKeys.call([])
  end
end
