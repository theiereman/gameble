class DuelScreen
  Call = Data.define(:stat, :direction, :open)
  Reveal = Data.define(:number, :outcome, :mine, :theirs, :stat, :direction, :score, :other_score, :decided_on_value, :automatic)

  attr_reader :view

  delegate :token, :move_number, :state, :round, :mine, :theirs, :hand, :current_call, :deadline, :server_time, to: :view

  def initialize(duel, seat, locale:)
    @duel = duel
    @seat = seat
    @locale = locale
    @view = Game::DuelView.for(duel, seat)
  end

  def stream_key = @seat.stream_key

  def started? = %i[active finished].include?(state)

  def finished? = state == :finished

  def waiting? = state == :challenged

  def challenger? = mine.role == :challenger

  def opponent
    return @opponent if defined?(@opponent)

    other = @duel.seats.find { it.role != @seat.role }
    @opponent = other&.player_id && Accounts::PlayerById.call(other.player_id)
  end

  def turn
    return unless state == :active

    calling = view.caller == mine.role
    return calling ? :call : :their_call if current_call.nil?

    calling ? :their_answer : :answer
  end

  def clock? = deadline.present? && (waiting? || turn.present?)

  def clock_mine? = waiting? ? !challenger? : %i[call answer].include?(turn)

  def title(card) = titles[card.card_season_id].to_s

  def position(card) = mine.deck.index(card) + 1

  def played?(side, card) = side.played.include?(card.card_season_id)

  def score = mine.score

  def other_score = theirs.score

  def margin_gap = mine.margin - theirs.margin

  def outcome
    case view.result
    when nil then nil
    when :draw then :draw
    when mine.role then :win
    else :loss
    end
  end

  def decided_on_margin? = finished? && score == other_score && view.result != :draw

  def calls
    Game::DuelStat::STATS.flat_map do |stat|
      Game::DuelStat::DIRECTIONS.map { |direction| Call.new(stat:, direction:, open: mine.stats_left.include?(stat)) }
    end
  end

  def reveals
    @reveals ||= begin
      won = Hash.new(0)
      view.rounds.map do |played|
        won[played.winner] += 1
        reveal(played, won)
      end
    end
  end

  private
    def titles
      @titles ||= Catalog::CardViews.call((mine.deck + theirs.deck).map(&:card_season_id), locale: @locale).transform_values(&:title)
    end

    def reveal(played, won)
      called = played.caller == mine.role
      Reveal.new(number: played.number, outcome: round_outcome(played.winner), stat: played.stat, direction: played.direction,
        mine: called ? played.caller_card : played.answer_card, theirs: called ? played.answer_card : played.caller_card,
        score: won[mine.role], other_score: won[theirs.role], decided_on_value: played.decided_on_value,
        automatic: played.caller_automatic || played.answer_automatic)
    end

    def round_outcome(winner)
      case winner
      when nil then :drawn
      when mine.role then :won
      else :lost
      end
    end
end
