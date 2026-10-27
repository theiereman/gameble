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
