module Catalog
  # Builds a season's sets from its rows (SeasonRows::Row) when it is
  # published (CAP-6, AD-5). Pure functions, one per kind, each returning
  # `[{ kind:, key:, params:, members: [card_season_id, …] }]` with the
  # members in their set's order. `params` holds what a later screen needs to
  # name the set; a key is never parsed back.
  #
  #   Catalog::SetBuilder.call(rows) # => publisher sets, tomes, best-of-years
  module SetBuilder
    # A publisher needs this many cards for a set.
    PUBLISHER_MIN_CARDS = 5
    # A tome's volumes hold about this many cards.
    TOME_SIZE = 30
    # A best-of-year set holds at most this many cards.
    BEST_OF_YEAR_SIZE = 10

    def self.call(rows)
      publishers(rows) + tomes(rows) + best_of_year(rows)
    end

    # One set per exact publisher name with at least PUBLISHER_MIN_CARDS
    # cards, its cards by release date then card id. Publishers are taken in
    # byte order; each takes the first unused of `base`, `base-2`, `base-3`, …
    # where `base` is the parameterized name, or "publisher" when nothing
    # Latin is left of it.
    def self.publishers(rows)
      used = ::Set.new
      rows.reject { |row| row.publisher.nil? }.group_by(&:publisher)
        .select { |_, members| members.size >= PUBLISHER_MIN_CARDS }
        .sort_by { |name, _| name }
        .map do |name, members|
          base = name.parameterize(locale: :en).presence || "publisher"
          key = base
          suffix = 1
          key = "#{base}-#{suffix += 1}" while used.include?(key)
          used << key
          { kind: "publisher", key:, params: { "publisher" => name }, members: by_release(members) }
        end
    end

    # A card sits in the tome of its first genre; a card without genre in
    # none. A genre's n cards, by release date then card id, are split into
    # v = max((n + TOME_SIZE / 2) / TOME_SIZE, 1) volumes of consecutive
    # cards, the first n % v volumes one card larger.
    def self.tomes(rows)
      rows.reject { |row| row.genres.empty? }.group_by { |row| row.genres.first }
        .sort_by { |genre, _| genre }
        .flat_map do |genre, members|
          ordered = by_release(members)
          n = ordered.size
          v = [ (n + TOME_SIZE / 2) / TOME_SIZE, 1 ].max
          offset = 0
          (1..v).map do |volume|
            size = n / v + (volume <= n % v ? 1 : 0)
            slice = ordered[offset, size]
            offset += size
            { kind: "tome", key: "#{genre}-#{volume}", params: { "genre" => genre, "volume" => volume, "volumes" => v }, members: slice }
          end
        end
    end

    # One set per release year, its BEST_OF_YEAR_SIZE best cards (fewer when
    # the year has fewer) by rating, then prestige score, then card id.
    def self.best_of_year(rows)
      rows.group_by { |row| row.release_date.year }.sort.map do |year, members|
        ranked = members.sort_by { |row| [ -row.rating, -row.prestige_score, row.card_id ] }.first(BEST_OF_YEAR_SIZE)
        { kind: "best_of_year", key: year.to_s, params: { "year" => year }, members: ranked.map(&:id) }
      end
    end

    def self.by_release(rows)
      rows.sort_by { |row| [ row.release_date, row.card_id ] }.map(&:id)
    end
    private_class_method :by_release
  end
end
