class DuelLobby
  Received = Data.define(:token, :move_number, :challenger)
  Seated = Data.define(:token, :active, :opponent)

  def initialize(player, decks:)
    @player = player
    @decks = decks
  end

  def received
    seat = held.invited
    seat && Received.new(token: seat.duel.token, move_number: seat.duel.move_number, challenger: other_player(seat))
  end

  def seated
    seat = held.seated
    seat && Seated.new(token: seat.duel.token, active: seat.duel.state == "active", opponent: other_player(seat))
  end

  def decks = @decks.rows.select(&:complete?)

  def friends = @friends ||= Game::FriendsOf.call(@player).select { Game::Visibility.open_to_friends?(it) }

  def closed? = !Game::Visibility.open_to_friends?(@player)

  private
    def held = @held ||= Game::HeldSeats.call(@player)

    def other_player(seat)
      other = seat.duel.seats.find { it.role != seat.role }
      other&.player_id && Accounts::PlayerById.call(other.player_id)
    end
end
