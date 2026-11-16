class DuelLobby
  Received = Data.define(:token, :move_number, :challenger, :deadline)
  Seated = Data.define(:token, :active, :opponent, :deadline)

  attr_reader :player

  def initialize(player)
    @player = player
  end

  def received
    seat = held.invited
    seat && Received.new(token: seat.duel.token, move_number: seat.duel.move_number, challenger: other_player(seat),
      deadline: seat.duel.move_deadline_at)
  end

  def seated
    seat = held.seated
    seat && Seated.new(token: seat.duel.token, active: seat.duel.state == "active", opponent: other_player(seat),
      deadline: seat.duel.move_deadline_at)
  end

  def reachable = @reachable ||= Game::ReachableFriends.call(@player)

  def befriended? = Game::FriendsOf.call(@player).any?

  def closed? = !Game::Visibility.open_to_friends?(@player)

  private
    def held = @held ||= Game::HeldSeats.call(@player)

    def other_player(seat)
      other = seat.duel.seats.find { it.role != seat.role }
      other&.player_id && Accounts::PlayerById.call(other.player_id)
    end
end
