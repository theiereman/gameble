class BottomSheetComponent < ViewComponent::Base
  ACTIONS = [
    "click@document->bottom-sheet#openFrom",
    "click->bottom-sheet#closeOnScrim",
    "keydown->bottom-sheet#keydown",
    "pointermove->bottom-sheet#move",
    "pointerup->bottom-sheet#release",
    "pointercancel->bottom-sheet#cancelDrag"
  ].join(" ").freeze

  def initialize(id:, title:)
    @id = id
    @title = title
  end

  private
    attr_reader :id, :title

    def title_id = "#{id}-title"
end
