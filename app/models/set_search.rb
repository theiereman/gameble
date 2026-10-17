module SetSearch
  MAX_QUERY = 100
  LIMIT = 50

  Result = Data.define(:sets, :count)
  NONE = Result.new(sets: [], count: 0)

  def self.call(season:, query:, locale:)
    needle = normalize(clean(query))
    return NONE if season.nil? || needle.empty?

    I18n.with_locale(locale) do
      found = Catalog::SeasonShelf.every_kind(season:).filter_map do |set|
        name = normalize(SetLabel.for(set))
        [ name.start_with?(needle) ? 0 : 1, name, set.id, set ] if name.include?(needle) || kind_name(set.kind).include?(needle)
      end
      ordered = found.sort_by { |first, name, id, _set| [ first, name, id ] }.map(&:last)
      Result.new(sets: ordered.first(LIMIT), count: ordered.size)
    end
  end

  def self.clean(query)
    query.to_s.strip.first(MAX_QUERY)
  end

  def self.normalize(text)
    text.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase
  end

  def self.kind_name(kind)
    normalize(I18n.t("library.set_kinds.#{kind}"))
  end

  private_class_method :normalize, :kind_name
end
