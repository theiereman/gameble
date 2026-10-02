# The name of a set on a screen, in the current locale (epic 4 R7, AD-18),
# built from its kind and `params`, never from its key: a publisher set is
# the publisher's own name; a tome "<genre> · Tome <volume>"; a best of year
# "Best rated of <year>". A genre missing from `catalog.genres` (one Steam
# adds later) is its key humanised, in English whatever the locale. A
# malformed set (unknown kind, tome without genre) raises ArgumentError.
#
#   SetLabel.for(set) # => "Action · Tome 2"
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

  def self.genre(key)
    I18n.t(key, scope: "catalog.genres", default: key.to_s.humanize)
  end
end
