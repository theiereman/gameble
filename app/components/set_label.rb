# The name of a set on a screen, in the current locale, built from its kind
# and `params`, never from its key: a theme set is its theme's name, a
# franchise or studio set the franchise's or studio's own name, a hall of
# fame set its name from `catalog.hall_of_fame`, the UFOs "The UFOs". A
# theme without a stored name is its key humanised, in English whatever
# the locale. A malformed set (a kind without a name, a theme or hall of
# fame set without its param) raises ArgumentError. `set` is anything with
# `kind` and `params` (a Catalog::Set, a Catalog::SetRef).
#
#   SetLabel.for(set) # => "Roguelike"
#
# `genre` names a card's genre, its main theme.
module SetLabel
  def self.for(set)
    params = set.params || {}
    case set.kind
    when "theme"
      raise ArgumentError, "a theme set without theme: #{params.inspect}" if params["theme"].blank?

      genre(params["theme"])
    when "franchise" then params["franchise"]
    when "studio" then params["studio"]
    when "hall_of_fame"
      raise ArgumentError, "a hall of fame set without its key: #{params.inspect}" if params["hall_of_fame"].blank?

      I18n.t(params["hall_of_fame"], scope: "catalog.hall_of_fame")
    when "ufo" then I18n.t("catalog.sets.ufos")
    else raise ArgumentError, "unknown set kind: #{set.kind.inspect}"
    end
  end

  def self.genre(key)
    Catalog::ThemeNames.of(key) || key.to_s.humanize
  end
end
