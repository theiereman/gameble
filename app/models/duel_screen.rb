class DuelScreen
  REVEAL_WINDOW = 10

  Reveal = Data.define(:number, :outcome, :mine, :theirs, :called, :stat, :direction, :score, :other_score, :decided_on_value,
    :automatic, :mine_automatic, :theirs_automatic) do
    def caller_card = called ? mine : theirs

    def answer_card = called ? theirs : mine
  end

  Rematch = Data.define(:friend_token, :deck_token, :unavailable, :practice)

  attr_reader :view

  delegate :token, :move_number, :state, :round, :mine, :theirs, :hand, :current_call, :deadline, :server_time, :away_until, to: :view

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

  def viewer = @viewer ||= Accounts::PlayerById.call(@seat.player_id)

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

  def card_view(card) = card_views.fetch(card.card_season_id)

  def title(card) = card_views[card.card_season_id]&.title.to_s

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

  def capsule = (@duel.capsule.to_sym if outcome == :win && @duel.capsule)

  def decided_on_margin? = finished? && score == other_score && view.result != :draw

  def stat_open?(stat) = mine.stats_left.include?(stat)

  def reveals
    @reveals ||= begin
      won = Hash.new(0)
      view.rounds.map do |played|
        won[played.winner] += 1
        reveal_of(played, won)
      end
    end
  end

  def reveal
    return @reveal if defined?(@reveal)

    answered = @duel.rounds.select(&:answered_at).max_by(&:number)
    latest = answered && move_number == (2 * reveals.size) + 1
    @reveal = (reveals.last if latest && answered.answered_at >= view.server_time - REVEAL_WINDOW)
  end

  def rematch
    return unless finished? && viewer
    return Rematch.new(friend_token: nil, deck_token: @seat.deck_token, unavailable: nil, practice: true) if @duel.practice

    row = opponent && Game::ReachableFriends.call(viewer).find { it.player.id == opponent.id }
    Rematch.new(friend_token: opponent&.token, deck_token: @seat.deck_token, unavailable: row ? (:in_duel if row.in_duel) : :offline, practice: false)
  end

  private
    def card_views
      @card_views ||= Catalog::CardViews.call((mine.deck + theirs.deck).map(&:card_season_id), locale: @locale)
    end

    def reveal_of(played, won)
      called = played.caller == mine.role
      Reveal.new(number: played.number, outcome: round_outcome(played.winner), stat: played.stat, direction: played.direction,
        mine: called ? played.caller_card : played.answer_card, theirs: called ? played.answer_card : played.caller_card, called:,
        score: won[mine.role], other_score: won[theirs.role], decided_on_value: played.decided_on_value,
        automatic: played.caller_automatic || played.answer_automatic,
        mine_automatic: called ? played.caller_automatic : played.answer_automatic,
        theirs_automatic: called ? played.answer_automatic : played.caller_automatic)
    end

    def round_outcome(winner)
      case winner
      when nil then :drawn
      when mine.role then :won
      else :lost
      end
    end
end
