require "test_helper"

class BottomSheetHelperTest < ActionView::TestCase
  test "an opener is a link to the sheet that says it opens a dialog" do
    link = tag.a("Pick", **bottom_sheet_opener("pick"))

    assert_dom_equal '<a href="#pick" aria-haspopup="dialog" aria-controls="pick" data-bottom-sheet-opens="pick">Pick</a>', link
  end
end
