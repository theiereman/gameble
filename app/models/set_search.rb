module SetSearch
  MAX_QUERY = 100
  LIMIT = 50
  KIND_LIMIT = 12

  Result = Data.define(:sets, :count)
  NONE = Result.new(sets: [], count: 0)

  def self.call(season:, query:, locale:)
    needle = normalize(clean(query))
    return NONE if season.nil? || needle.empty?

    I18n.with_locale(locale) do
      found = ranked(Catalog::SeasonSets.every_kind(season:), needle) { |set, name| name.include?(needle) || kind_name(set.kind).include?(needle) }
      Result.new(sets: found.first(LIMIT), count: found.size)
    end
  end

  def self.in_kind(season:, kind:, query:, locale:, except: [], limit: KIND_LIMIT)
    return NONE if season.nil?

    needle = normalize(clean(query))
    I18n.with_locale(locale) do
      found = ranked(Catalog::SeasonSets.every_kind(season:).where(kind: kind.to_s), needle) { |_set, name| name.include?(needle) }
      Result.new(sets: found.reject { [ it.kind, it.key ].in?(except) }.first(limit), count: found.size)
    end
  end

  def self.clean(query)
    query.to_s.strip.first(MAX_QUERY)
  end

  def self.ranked(sets, needle)
    sets.filter_map { |set|
      name = normalize(SetLabel.for(set))
      [ name.start_with?(needle) ? 0 : 1, name, set.id, set ] if yield(set, name)
    }.sort_by { |first, name, id, _set| [ first, name, id ] }.map(&:last)
  end

  def self.normalize(text)
    text.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase
  end

  def self.kind_name(kind)
    normalize(I18n.t("library.set_kinds.#{kind}"))
  end

  private_class_method :ranked, :kind_name
end
