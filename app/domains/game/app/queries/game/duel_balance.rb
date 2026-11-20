module Game
  module DuelBalance
    Figures = Data.define(:finished, :forfeited, :first_caller_wins, :decided_on_margin, :with_automatic_move, :stats_called) do
      def played = finished - forfeited
    end
    Recipe = Data.define(:name, :decks, :wins)
    Practice = Data.define(:archetype, :figures, :bot_wins)
    Report = Data.define(:rules_version, :live, :recipes, :practice, :practice_total)
    Call = Data.define(:duel_id, :stat, :direction, :automatic)

    ROLES = %w[challenger opponent].freeze
    ARCHETYPE_ORDER = (DeckArchetypes::NAMES + [ DeckArchetypes::OTHER ]).freeze
    COLUMNS = %i[id practice result first_caller forfeited_by challenger_score opponent_score bot_archetype challenger_cards
      opponent_cards].freeze

    def self.versions
      (Duel.where(state: "finished").distinct.pluck(:rules_version) | [ DuelRules::VERSION ]).sort.reverse
    end

    # shortcut: aggregates the version's finished duels in Ruby; move the counts to SQL once a version holds thousands of duels.
    def self.call(rules_version)
      finished = Duel.where(state: "finished", rules_version:)
      calls = DuelRound.where(duel_id: finished.select(:id))
        .pluck(:duel_id, :stat, :direction, Arel.sql("caller_automatic OR answer_automatic"))
        .map { Call.new(*it) }.group_by(&:duel_id)
      practice, live = finished.select(*COLUMNS).partition(&:practice)

      Report.new(rules_version:, live: figures(live, calls), recipes: recipes(live), practice: practice_rows(practice, calls),
        practice_total: figures(practice, calls))
    end

    def self.figures(duels, calls)
      played = duels.reject(&:forfeited_by)
      Figures.new(
        finished: duels.size,
        forfeited: duels.size - played.size,
        first_caller_wins: played.count { it.result == it.first_caller },
        decided_on_margin: played.count { it.challenger_score == it.opponent_score && it.result != "draw" },
        with_automatic_move: played.count { calls.fetch(it.id, []).any?(&:automatic) },
        stats_called: played.flat_map { calls.fetch(it.id, []) }.map { [ it.stat.to_sym, it.direction.to_sym ] }.tally
      )
    end

    def self.recipes(duels)
      decks = duels.reject(&:forfeited_by).flat_map do |duel|
        ROLES.map { |role| [ DeckArchetypes.classify(duel.cards(role)), duel.result == role ] }
      end
      by_name = decks.group_by(&:first)
      ARCHETYPE_ORDER.filter_map do |name|
        Recipe.new(name:, decks: by_name[name].size, wins: by_name[name].count(&:last)) if by_name.key?(name)
      end
    end

    def self.practice_rows(duels, calls)
      by_archetype = duels.group_by { it.bot_archetype || DeckArchetypes::OTHER }
      ARCHETYPE_ORDER.filter_map do |archetype|
        group = by_archetype[archetype] or next
        Practice.new(archetype:, figures: figures(group, calls), bot_wins: group.count { bot_won?(it) })
      end
    end

    def self.bot_won?(duel) = duel.forfeited_by.nil? && duel.result == PracticeBot::ROLE.to_s

    private_class_method :figures, :recipes, :practice_rows, :bot_won?
  end
end
