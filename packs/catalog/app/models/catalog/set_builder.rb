module Catalog
  # Builds a season's sets from its rows (SeasonRows::Row) when it is
  # published. Pure functions, one per kind, each returning
  # `[{ kind:, key:, params:, members: [card_season_id, …], tiers: { tier => required } }]`
  # with the members in their set's order, by release date then card id.
  # `params` holds what a later screen needs to name the set; a key is never
  # parsed back.
  #
  #   Catalog::SetBuilder.call(rows) # => theme sets, then the UFOs
  module SetBuilder
    UFOS = "ufos".freeze

    def self.call(rows)
      themes(rows) + ufos(rows)
    end

    # One set per theme among the cards' genres, in the order of the theme
    # list, holding every card that has it; a genre outside the list is
    # ignored.
    def self.themes(rows)
      members = rows.each_with_object(Hash.new { |hash, theme| hash[theme] = [] }) do |row, by_theme|
        row.genres.uniq.each { |genre| by_theme[genre] << row if Themes.key?(genre) }
      end
      Themes.keys.filter_map do |theme|
        next unless members.key?(theme)

        ordered = by_release(members[theme])
        { kind: "theme", key: theme, params: { "theme" => theme }, members: ordered, tiers: Themes.tiers(ordered.size) }
      end
    end

    # The cards of no theme, in one set; none when every card has a theme.
    def self.ufos(rows)
      ordered = by_release(rows.reject { |row| row.genres.any? { |genre| Themes.key?(genre) } })
      return [] if ordered.empty?

      [ { kind: "ufo", key: UFOS, params: {}, members: ordered, tiers: { Themes::COMPLETE => ordered.size } } ]
    end

    def self.by_release(rows)
      rows.sort_by { |row| [ row.release_date, row.card_id ] }.map(&:id)
    end
    private_class_method :by_release
  end
end
