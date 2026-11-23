module SlotPurchasesHelper
  def slot_ordinal(slot, words: false, article: false)
    form = [ (article ? "indefinite" : "bare"), ("words" if words) ].compact.join("_")
    t("slot_purchases.ordinals.#{slot}.#{form}")
  end

  def slot_purchase_title(kind, slot)
    safe_join([
      tag.span(t("slot_purchases.confirmation.title.#{kind}", ordinal: slot_ordinal(slot, article: true)), aria: { hidden: true }),
      tag.span(t("slot_purchases.confirmation.spoken_title.#{kind}", ordinal: slot_ordinal(slot, words: true, article: true)), class: "visually-hidden")
    ])
  end

  def slot_price_line(offer, id:, class: nil)
    tag.p(t("slot_purchases.price_line_html", price: render(PicoinAmountComponent.new(amount: offer.price))), id:, class:)
  end

  def slot_purchase_opener_path(offer, aim = {})
    new_slot_purchase_path(capacity: SlotPurchasesController::KINDS.key(offer.kind), slot: offer.slot, **aim)
  end

  def goal_bought_status(goal)
    safe_join([
      tag.span(t("goals.bought.title", ordinal: slot_ordinal(goal.position)), aria: { hidden: true }, class: "goal-control__limit"),
      tag.span(t("goals.bought.spoken", ordinal: slot_ordinal(goal.position, words: true)), class: "visually-hidden"),
      " · ",
      t("goals.bought.line", set: goal_set_name(goal), number: goal.position)
    ])
  end

  def goal_bought_sentence(goal)
    [ t("goals.bought.spoken", ordinal: slot_ordinal(goal.position, words: true)), t("goals.bought.line", set: goal_set_name(goal), number: goal.position) ].join(" · ")
  end
end
