module BottomSheetHelper
  def bottom_sheet_opener(id, page: nil)
    return { href: page, aria: { haspopup: "dialog" } } if page && hotwire_native_app?

    { href: "##{id}", aria: { haspopup: "dialog", controls: id }, data: { bottom_sheet_opens: id } }
  end
end
