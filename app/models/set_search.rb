module SetSearch
  MAX_QUERY = 100
  LIMIT = 50
  KIND_LIMIT = 12

  Result = Data.define(:sets, :count)
  NONE = Result.new(sets: [], count: 0)

  def self.call(season:, query:, locale:, own_sets: {})
    needle = normalize(clean(query))
    return NONE if season.nil? || needle.empty?

    I18n.with_locale(locale) do
      game_sets = named(Catalog::SeasonSets.every_kind(season:)).select { |set, name| name.include?(needle) || kind_name(set.kind).include?(needle) }
      mine = own_sets.map { |own_set, name| [ own_set, normalize(name) ] }.select { |_own_set, name| name.include?(needle) }
      found = ranked(game_sets + mine, needle)
      Result.new(sets: found.first(LIMIT), count: found.size)
    end
  end

  def self.in_kind(season:, kind:, query:, locale:, except: [], limit: KIND_LIMIT)
    return NONE if season.nil?

    needle = normalize(clean(query))
    I18n.with_locale(locale) do
      found = ranked(named(Catalog::SeasonSets.every_kind(season:).where(kind: kind.to_s)).select { |_set, name| name.include?(needle) }, needle)
      Result.new(sets: found.reject { [ it.kind, it.key ].in?(except) }.first(limit), count: found.size)
    end
  end

  def self.clean(query)
    query.to_s.strip.first(MAX_QUERY)
  end

  def self.named(sets)
    sets.sort_by(&:id).map { [ it, normalize(SetLabel.for(it)) ] }
  end

  def self.ranked(named_sets, needle)
    named_sets.each_with_index
      .sort_by { |(_set, name), index| [ name.start_with?(needle) ? 0 : 1, name, index ] }
      .map { |(set, _name), _index| set }
  end

  def self.normalize(text)
    text.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase
  end

  def self.kind_name(kind)
    normalize(I18n.t("library.set_kinds.#{kind}"))
  end

  private_class_method :named, :ranked, :kind_name
end
