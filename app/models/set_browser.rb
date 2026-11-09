class SetBrowser
  MY_SETS = "mine".freeze
  IN_PROGRESS = "in_progress".freeze
  NOT_STARTED = "not_started".freeze
  COMPLETE = "complete".freeze
  STATES = [ NOT_STARTED, IN_PROGRESS, COMPLETE ].freeze
  TIERS = Catalog::TierTable::RANKS

  Entry = Data.define(:set, :own_set, :standing, :name) do
    def own? = !own_set.nil?

    def kind = own? ? MY_SETS : set.kind

    def state
      return COMPLETE if standing.complete?

      standing.started? ? IN_PROGRESS : NOT_STARTED
    end

    def tier = standing.reached_tier

    def closeness = [ standing.missing || 0, standing.total - standing.held, -standing.share, name ]

    def completed_at = standing.completed_at || standing.gained_at
  end

  attr_reader :query, :goals

  def initialize(season:, player:, own_sets:, goals:, filters:)
    @season = season
    @player = player
    @own_sets = own_sets
    @goals = goals
    @filters = filters
    @query = SetSearch.clean(filters[:q].is_a?(String) ? filters[:q] : "")
  end

  def entries
    @entries ||= begin
      needle = SetSearch.normalize(query)
      kept = every_entry.select { within_filters?(it) && matches?(it, needle) }
      needle.empty? ? in_browsing_order(kept) : SetSearch.ranked(kept.map { [ it, it.name ] }, needle)
    end
  end

  def kinds = @kinds ||= [ *Catalog::SetKind::ALL, MY_SETS ] & every_entry.map(&:kind).uniq

  def chosen_kinds = @chosen_kinds ||= chosen(:kind, kinds)

  def chosen_states = @chosen_states ||= chosen(:state, STATES)

  def chosen_tiers = @chosen_tiers ||= chosen(:tier, TIERS)

  def chosen_goals = @chosen_goals ||= goals.chosen(list(:goals))

  def filter_counts
    { kind: chosen_kinds.size, state: chosen_states.size, tier: chosen_tiers.size, goals: chosen_goals.size }
  end

  private
    def list(key) = Array.wrap(@filters[key]).grep(String)

    def chosen(key, allowed) = allowed & list(key)

    def every_entry = @every_entry ||= game_entries + own_entries

    def game_entries
      return [] if @season.nil?

      sets = Catalog::SeasonSets.every_kind(season: @season).to_a
      standings = Game::SetsInProgress.call(@player, season: @season)
      figures = Catalog::SetFigures.call(sets.map(&:id).reject { standings.key?(it) })
      SetSearch.named(sets).filter_map do |set, name|
        standing = standings[set.id] || figures[set.id]&.then { Game::SetStanding.unstarted(set_id: set.id, total: it.total, tiers: it.tiers) }
        Entry.new(set:, own_set: nil, standing:, name:) if standing
      end
    end

    def own_entries
      @own_sets.map { |own_set, name| Entry.new(set: nil, own_set:, standing: own_set.to_set_standing, name: SetSearch.normalize(name)) }
    end

    def within_filters?(entry)
      allows?(chosen_kinds, entry.kind) && allows?(chosen_states, entry.state) && allows?(chosen_tiers, entry.tier) &&
        (chosen_goals.empty? || chosen_goals.any? { aimed_at?(it, entry) })
    end

    def allows?(chosen, value) = chosen.empty? || chosen.include?(value)

    def aimed_at?(goal, entry)
      entry.own? ? goal.target.aims_at?(custom_set: entry.own_set.token) : goal.target.aims_at?(kind: entry.set.kind, key: entry.set.key)
    end

    def matches?(entry, needle)
      needle.empty? || entry.name.include?(needle) || SetSearch.kind_name(entry.kind).include?(needle)
    end

    def in_browsing_order(entries)
      entries.each_with_index.sort_by { |entry, index| [ *browsing_rank(entry), index ] }.map(&:first)
    end

    def browsing_rank(entry)
      case entry.state
      when IN_PROGRESS then [ 0, *entry.closeness ]
      when NOT_STARTED then [ 1, entry.name ]
      else [ 2, *most_recent_first(entry.completed_at), entry.name ]
      end
    end

    def most_recent_first(time) = time ? [ 0, -time.to_r ] : [ 1, 0 ]
end
