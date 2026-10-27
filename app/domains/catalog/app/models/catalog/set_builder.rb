module Catalog
  # Builds a season's sets from its rows (SeasonRows::Row) when it is
  # published. Pure functions, one per kind, each returning
  # `[{ kind:, key:, params:, members: [card_season_id, …], tiers: { tier => required } }]`
  # with the members in their set's order, by release date then card id,
  # and the tiers TierTable gives the set's size, whatever its kind.
  # `params` holds what a later screen needs to name the set; a key is never
  # parsed back. Names and keys of franchises and studios follow SetNames:
  # names whose merge forms are equal make one set, named after the name most
  # of its games carry (the alphabetically first on a tie) and keyed by that
  # name's form; sets whose keys are equal merge.
  #
  #   Catalog::SetBuilder.call(rows) # => theme sets, franchises, studios, hall of fame, then the UFOs
  module SetBuilder
    UFOS = "ufos".freeze
    MIN_GAMES = 3
    STUDIO_REVIEW_FLOOR = 20_000

    def self.call(rows)
      themes(rows) + franchises(rows) + studios(rows) + hall_of_fame(rows) + ufos(rows)
    end

    # One set per theme among the cards' genres, in the order of the
    # theme list, holding every card that has it; a genre outside the list is
    # ignored. `theme_keys` is Themes.keys, which a caller building several
    # kinds reads once.
    def self.themes(rows, theme_keys: Themes.keys)
      keys = theme_keys
      listed = keys.to_set
      members = rows.each_with_object(Hash.new { |hash, theme| hash[theme] = [] }) do |row, by_theme|
        row.genres.uniq.each { |genre| by_theme[genre] << row if listed.include?(genre) }
      end
      keys.filter_map do |theme|
        next unless members.key?(theme)

        ordered = by_release(members[theme])
        { kind: "theme", key: theme, params: { "theme" => theme }, members: ordered, tiers: TierTable.tiers(ordered.size) }
      end
    end

    # One set per franchise of at least MIN_GAMES games, by key, unless it is
    # named like a developer or publisher of the season or no more than half
    # of its games' English titles match its name.
    def self.franchises(rows)
      companies = rows.flat_map { |row| [ *row.developers, row.publisher ] }.compact.to_set { |name| SetNames.company_form(name) }
      named(rows) { |row| row.franchises.map { |name| SetNames.franchise(name) } }
        .select { |set| set[:rows].size >= MIN_GAMES && companies.exclude?(SetNames.company_form(set[:name])) && named_in_titles?(set) }
        .map { |set| named_set("franchise", set) }
    end

    # One set per studio of at least MIN_GAMES games, by key, a game counting
    # under its first developer only, when its most-reviewed game has
    # STUDIO_REVIEW_FLOOR reviews.
    def self.studios(rows)
      named(rows) { |row| row.developers.first(1).map { |name| SetNames.company(name) } }
        .select { |set| set[:rows].size >= MIN_GAMES && set[:rows].map { |row| row.review_count.to_i }.max >= STUDIO_REVIEW_FLOOR }
        .map { |set| named_set("studio", set) }
    end

    # One set per hall of fame rule some card meets, in HallOfFame's order.
    def self.hall_of_fame(rows)
      HallOfFame.keys.filter_map do |key|
        ordered = by_release(rows.select { |row| HallOfFame.selects?(key, row) })
        next if ordered.empty?

        { kind: "hall_of_fame", key:, params: { "hall_of_fame" => key }, members: ordered, tiers: TierTable.tiers(ordered.size) }
      end
    end

    # The cards of no theme, in one set; none when every card has a theme.
    def self.ufos(rows, theme_keys: Themes.keys)
      listed = theme_keys.to_set
      ordered = by_release(rows.reject { |row| row.genres.any? { |genre| listed.include?(genre) } })
      return [] if ordered.empty?

      [ { kind: "ufo", key: UFOS, params: {}, members: ordered, tiers: TierTable.tiers(ordered.size) } ]
    end

    def self.by_release(rows)
      rows.sort_by { |row| [ row.release_date, row.card_id ] }.map(&:id)
    end

    # The rows grouped under the names the block gives each of them, by key:
    # `{ key:, name:, rows: }`. A name whose merge form is blank is no name.
    def self.named(rows, &names)
      by_merge_form = rows.each_with_object({}) do |row, groups|
        names.call(row).filter_map { |name| SetNames.merge_form(name).presence&.then { |merge_form| [ merge_form, name ] } }
          .uniq(&:first).each do |merge_form, name|
            group = groups[merge_form] ||= { names: Hash.new(0), rows: [] }
            group[:names][name] += 1
            group[:rows] << row
          end
      end
      by_merge_form.values.group_by { |group| SetNames.key(SetNames.form(most_carried(group[:names]))) }.sort.map do |key, groups|
        names = groups.map { |group| group[:names] }.reduce { |merged, more| merged.merge(more) { |_, count, other| count + other } }
        { key:, name: most_carried(names), rows: groups.flat_map { |group| group[:rows] }.uniq }
      end
    end

    # The name the most games carry, the alphabetically first on a tie.
    def self.most_carried(counts)
      counts.min_by { |name, count| [ -count, name ] }.first
    end

    def self.named_in_titles?(set)
      return true if SetNames.exempt_from_titles?(set[:name])

      set[:rows].count { |row| SetNames.title_matches?(row.title, set[:name]) } * 2 > set[:rows].size
    end

    def self.named_set(kind, set)
      ordered = by_release(set[:rows])
      { kind:, key: set[:key], params: { kind => set[:name] }, members: ordered, tiers: TierTable.tiers(ordered.size) }
    end

    private_class_method :by_release, :named, :most_carried, :named_in_titles?, :named_set
  end
end
