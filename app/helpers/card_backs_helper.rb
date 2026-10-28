module CardBacksHelper
  SetRef = Data.define(:kind, :params)

  def card_back_name(back)
    return set_label(back) if back.unlock.kind == :set_tier

    t("card_backs.names.#{back.key}")
  end

  def card_back_condition(back)
    return t("card_backs.conditions.set_tier", set: set_label(back)) if back.unlock.kind == :set_tier

    t("card_backs.conditions.#{back.unlock.kind}")
  end

  def card_back_image(back, size)
    image_tag vite_asset_path("images/pixel/#{back.asset}-#{size}.png"), alt: "", class: "back-picker__image"
  end

  private
    def set_label(back)
      kind, key = back.unlock.target
      SetLabel.for(SetRef.new(kind:, params: { kind => key }))
    end
end
