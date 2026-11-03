require "test_helper"

class BottomSheetComponentTest < ViewComponent::TestCase
  test "a modal dialog named by its title, its grip, a close button named in the locale and its body" do
    I18n.with_locale(:fr) { render_inline(BottomSheetComponent.new(id: "pick", title: "Choisir")) { "Les choix" } }

    assert_selector "dialog#pick.modal.bottom-sheet[aria-labelledby=pick-title][data-controller=bottom-sheet]"
    assert_selector "dialog#pick > .panel.panel--brackets.modal__panel.bottom-sheet__panel[data-bottom-sheet-target=panel]"
    assert_selector ".bottom-sheet__grip[data-action='pointerdown->bottom-sheet#grab'] > .modal__handle[aria-hidden=true]"
    assert_selector ".bottom-sheet__grip > .modal__head > p#pick-title.modal__title", text: "Choisir"
    assert_selector ".modal__head > button.modal__close[type=button][aria-label=Fermer][data-action='bottom-sheet#close'] svg.pixel-icon"
    assert_selector ".bottom-sheet__panel > .bottom-sheet__body[data-bottom-sheet-target=body]", text: "Les choix"
  end

  test "the dialog opens from a link to it anywhere on the page, closes on its scrim and follows a finger on its grip" do
    render_inline(BottomSheetComponent.new(id: "pick", title: "Pick")) { "Choices" }

    assert_equal %w[click@document->bottom-sheet#openFrom click->bottom-sheet#closeOnScrim keydown->bottom-sheet#keydown
      pointermove->bottom-sheet#move pointerup->bottom-sheet#release pointercancel->bottom-sheet#cancelDrag],
      page.find("dialog#pick", visible: :all)["data-action"].split
    assert_selector "button.modal__close[aria-label=Close]", visible: :all
  end

  test "a sheet renders closed, unless it is sent open for its controller to raise as a modal" do
    render_inline(BottomSheetComponent.new(id: "pick", title: "Pick")) { "Choices" }
    assert_selector "dialog#pick:not([open])", visible: :all

    render_inline(BottomSheetComponent.new(id: "pick", title: "Pick", open: true)) { "Choices" }
    assert_selector "dialog#pick[open][data-controller=bottom-sheet]", visible: :all
  end

  test "a wide sheet takes the wide modal's width where there is room" do
    render_inline(BottomSheetComponent.new(id: "pick", title: "Pick", wide: true)) { "Choices" }
    assert_selector "dialog#pick.modal.bottom-sheet.bottom-sheet--wide", visible: :all

    render_inline(BottomSheetComponent.new(id: "pick", title: "Pick")) { "Choices" }
    assert_no_selector ".bottom-sheet--wide", visible: :all
  end
end
