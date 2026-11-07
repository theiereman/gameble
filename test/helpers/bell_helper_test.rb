require "test_helper"

class BellHelperTest < ActionView::TestCase
  def subject_of(card: nil, partner_card: nil, set: nil)
    bell_reaction_subject(Game::BellItems::ReactionSubject.new(card:, partner_card:, set:))
  end

  test "a reaction line names the card, both cards of a trade, or the set the entry shows, in both languages" do
    assert_equal "Portal", subject_of(card: "Portal")
    assert_equal "Valve", subject_of(set: catalog_sets(:valve_one))
    assert_equal "Portal for Hades", subject_of(card: "Portal", partner_card: "Hades")
    I18n.with_locale(:fr) { assert_equal "Portal contre Hades", subject_of(card: "Portal", partner_card: "Hades") }
  end

  test "a reaction line whose card left the catalog names nothing" do
    assert_nil subject_of
  end
end
