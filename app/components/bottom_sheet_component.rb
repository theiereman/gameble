class BottomSheetComponent < ViewComponent::Base
  ACTIONS = [
    "click@document->bottom-sheet#openFrom",
    "click->bottom-sheet#closeOnScrim",
    "keydown->bottom-sheet#keydown",
    "pointermove->bottom-sheet#move",
    "pointerup->bottom-sheet#release",
    "pointercancel->bottom-sheet#cancelDrag"
  ].join(" ").freeze

  def initialize(id:, title:, open: false, wide: false)
    @id = id
    @title = title
    @open = open
    @wide = wide
  end

  private
    attr_reader :id, :title

    def open? = @open

    def classes = helpers.class_names("modal bottom-sheet", "bottom-sheet--wide": @wide)

    def title_id = "#{id}-title"
end
