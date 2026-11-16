class CreateGameDuels < ActiveRecord::Migration[8.1]
  STATES = %w[challenged cancelled refused lapsed active finished].freeze
  ROLES = %w[challenger opponent].freeze
  RESULTS = %w[challenger opponent draw].freeze
  CAPSULES = %w[granted automatic_move already_won_today].freeze
  STATUSES = %w[invited seated left].freeze
  STATS = %w[popularity rating release discovery circulation].freeze
  DIRECTIONS = %w[high low].freeze

  def change
    create_game_duels
    create_game_duel_seats
    create_game_duel_rounds
  end

  private

  def one_of(column, values) = values.map { "#{column} = '#{it}'" }.join(" OR ")

  def create_game_duels
    create_table :game_duels do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :state, null: false, default: "challenged"
      t.jsonb :challenger_cards
      t.jsonb :opponent_cards
      t.bigint :challenger_draw_order, array: true
      t.bigint :opponent_draw_order, array: true
      t.string :first_caller
      t.integer :move_number, null: false, default: 0
      t.datetime :move_deadline_at
      t.integer :challenger_score, limit: 2, null: false, default: 0
      t.integer :opponent_score, limit: 2, null: false, default: 0
      t.decimal :challenger_margin, precision: 5, scale: 1, null: false, default: 0
      t.decimal :opponent_margin, precision: 5, scale: 1, null: false, default: 0
      t.string :result
      t.string :capsule
      t.datetime :started_at
      t.datetime :ended_at
      t.timestamps

      t.index :move_deadline_at, where: "state = 'challenged' OR state = 'active'"
      t.check_constraint one_of(:state, STATES), name: "game_duels_state_check"
      t.check_constraint one_of(:first_caller, ROLES), name: "game_duels_first_caller_check"
      t.check_constraint one_of(:result, RESULTS), name: "game_duels_result_check"
      t.check_constraint one_of(:capsule, CAPSULES), name: "game_duels_capsule_check"
      t.check_constraint "(state = 'active' OR state = 'finished') = (started_at IS NOT NULL AND first_caller IS NOT NULL " \
        "AND challenger_cards IS NOT NULL AND opponent_cards IS NOT NULL " \
        "AND challenger_draw_order IS NOT NULL AND opponent_draw_order IS NOT NULL)", name: "game_duels_started_check"
      t.check_constraint "(state = 'challenged' OR state = 'active') = (ended_at IS NULL)", name: "game_duels_ended_check"
      t.check_constraint "(state = 'finished') = (result IS NOT NULL)", name: "game_duels_finished_check"
      t.check_constraint "capsule IS NULL OR state = 'finished'", name: "game_duels_capsule_finished_check"
      t.check_constraint "challenger_score BETWEEN 0 AND 10 AND opponent_score BETWEEN 0 AND 10 " \
        "AND challenger_score + opponent_score <= 10", name: "game_duels_scores_check"
      t.check_constraint "challenger_margin >= 0 AND opponent_margin >= 0", name: "game_duels_margins_check"
      t.check_constraint "move_number >= 0", name: "game_duels_move_number_check"
    end
  end

  def create_game_duel_seats
    create_table :game_duel_seats do |t|
      t.references :duel, null: false, index: false, foreign_key: { to_table: :game_duels }
      t.string :role, null: false
      t.references :player, index: true, foreign_key: { to_table: :accounts_players }
      t.string :deck_token
      t.uuid :stream_key, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.datetime :present_until
      t.string :status, null: false
      t.timestamps

      t.index %i[duel_id role], unique: true
      t.index :player_id, unique: true, where: "status = 'seated'", name: "index_game_duel_seats_on_seated_player_id"
      t.index :player_id, unique: true, where: "status = 'invited'", name: "index_game_duel_seats_on_invited_player_id"
      t.check_constraint one_of(:role, ROLES), name: "game_duel_seats_role_check"
      t.check_constraint one_of(:status, STATUSES), name: "game_duel_seats_status_check"
      t.check_constraint "role = 'opponent' OR status <> 'invited'", name: "game_duel_seats_invited_check"
      t.check_constraint "player_id IS NOT NULL OR status = 'left'", name: "game_duel_seats_player_check"
    end
  end

  def create_game_duel_rounds
    create_table :game_duel_rounds do |t|
      t.references :duel, null: false, index: false, foreign_key: { to_table: :game_duels }
      t.integer :number, limit: 2, null: false
      t.string :caller, null: false
      t.references :caller_card_season, null: false, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.references :answer_card_season, index: false, foreign_key: { to_table: :catalog_card_seasons }
      t.string :stat, null: false
      t.string :direction, null: false
      t.jsonb :caller_value
      t.jsonb :answer_value
      t.boolean :caller_automatic, null: false, default: false
      t.boolean :answer_automatic, null: false, default: false
      t.string :winner
      t.boolean :decided_on_value, null: false, default: false
      t.datetime :called_at, null: false
      t.datetime :answered_at
      t.timestamps

      t.index %i[duel_id number], unique: true
      t.check_constraint "number BETWEEN 1 AND 10", name: "game_duel_rounds_number_check"
      t.check_constraint one_of(:caller, ROLES), name: "game_duel_rounds_caller_check"
      t.check_constraint one_of(:stat, STATS), name: "game_duel_rounds_stat_check"
      t.check_constraint one_of(:direction, DIRECTIONS), name: "game_duel_rounds_direction_check"
      t.check_constraint one_of(:winner, ROLES), name: "game_duel_rounds_winner_check"
      t.check_constraint "(answered_at IS NULL) = (answer_card_season_id IS NULL)", name: "game_duel_rounds_answer_check"
      t.check_constraint "answered_at IS NOT NULL OR winner IS NULL", name: "game_duel_rounds_winner_answered_check"
    end
  end
end
