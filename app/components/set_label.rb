# The name of a set on a screen, in the current locale, built from its kind
# and `params`, never from its key: a theme set is its theme's name, a
# franchise or studio set the franchise's or studio's own name, a hall of
# fame set its name from `catalog.hall_of_fame`, the UFOs "The UFOs". The
# retired kinds keep their names: a publisher set is the publisher's own
# name; a tome "<genre> · Tome <volume>", its genre from
# `catalog.genres`; a best of year "Best rated of <year>". A theme or genre
# missing from the locales is its key humanised, in English whatever the
# locale. A malformed set (a kind without a name, a theme or hall of fame
# set without its param, a tome without genre) raises ArgumentError.
#
#   SetLabel.for(set) # => "Roguelike"
#
# A tome's heading adds the release-year range of its cards, one year when
# they are all of the same: SetLabel.heading(set, [ 2012, 2011 ]) # =>
# "Action · Tome 2 · 2011–2012". Any other set's heading is its name. `set`
# is anything with `kind` and `params` (a Catalog::Set, a SetSlots::SetRef).
#
# `genre` names a card's genre, its main theme.
module SetLabel
  def self.for(set)
    params = set.params
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
    when "publisher" then params["publisher"]
    when "tome"
      raise ArgumentError, "a tome without genre: #{params.inspect}" if params["genre"].blank?

      I18n.t("catalog.sets.tome", genre: tome_genre(params["genre"]), volume: params["volume"])
    when "best_of_year" then I18n.t("catalog.sets.best_of_year", year: params["year"])
    else raise ArgumentError, "unknown set kind: #{set.kind.inspect}"
    end
  end

  def self.heading(set, years)
    label = self.for(set)
    return label unless set.kind == "tome" && years.any?

    first, last = years.minmax
    I18n.t("catalog.sets.with_years", label:, years: first == last ? first.to_s : "#{first}–#{last}")
  end

  def self.genre(key)
    I18n.t(key, scope: "catalog.themes", default: key.to_s.humanize)
  end

  def self.tome_genre(key)
    I18n.t(key, scope: "catalog.genres", default: key.to_s.humanize)
  end
  private_class_method :tome_genre
end
