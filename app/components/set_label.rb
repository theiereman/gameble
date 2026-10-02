# The name of a set on a screen, in the current locale (epic 4 R7, AD-18),
# built from its kind and `params`, never from its key: a publisher set is
# the publisher's own name; a tome "<genre> · Tome <volume>"; a best of year
# "Best rated of <year>". A genre missing from `catalog.genres` (one Steam
# adds later) is its key humanised, in English whatever the locale. A
# malformed set (unknown kind, tome without genre) raises ArgumentError.
#
#   SetLabel.for(set) # => "Action · Tome 2"
#
# A tome's heading adds the release-year range of its cards, one year when
# they are all of the same: SetLabel.heading(set, [ 2012, 2011 ]) # =>
# "Action · Tome 2 · 2011–2012". Any other set's heading is its name. `set`
# is anything with `kind` and `params` (a Catalog::Set, a SetSlots::SetRef).
module SetLabel
  def self.for(set)
    params = set.params
    case set.kind
    when "publisher" then params["publisher"]
    when "tome"
      raise ArgumentError, "a tome without genre: #{params.inspect}" if params["genre"].blank?

      I18n.t("catalog.sets.tome", genre: genre(params["genre"]), volume: params["volume"])
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
    I18n.t(key, scope: "catalog.genres", default: key.to_s.humanize)
  end
end
