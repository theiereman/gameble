require "test_helper"

class CollectionHelperTest < ActionView::TestCase
  test "a set chip takes the label of its spine" do
    ref = Catalog::SetSlots::SetRef.new(kind: "theme", key: "portal", params: nil)
    assert_equal "Portal", set_chip_label(ref, { [ "theme", "portal" ] => "Portal" })
  end

  test "a set chip without a spine nor params is its humanised key" do
    ref = Catalog::SetSlots::SetRef.new(kind: "theme", key: "co_op_games", params: nil)
    assert_equal "Co op games", set_chip_label(ref, {})
  end
end
