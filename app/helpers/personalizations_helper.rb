module PersonalizationsHelper
  def personalization_fraction(count, total, suffix: nil)
    shown = safe_join([ tag.b(count), " / #{total}", (" #{suffix}" if suffix) ].compact)
    spoken = safe_join([ t("personalizations.show.fraction", count:, total:), (" #{suffix}" if suffix) ].compact)
    safe_join([ tag.span(shown, aria: { hidden: true }), tag.span(spoken, class: "visually-hidden") ])
  end
end
