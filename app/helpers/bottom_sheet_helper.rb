module BottomSheetHelper
  def bottom_sheet_opener(id)
    { href: "##{id}", aria: { haspopup: "dialog", controls: id }, data: { bottom_sheet_opens: id } }
  end
end
