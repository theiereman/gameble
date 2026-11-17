module Game
  module DuelSteps
    private

    def other_player(player, other)
      other.is_a?(Accounts::Player) && other.persisted? && other.id != player.id ? Success() : Failure(:not_a_friend)
    end

    def seated_duel(player, token)
      duel = Duel.joins(:seats).find_by(token:, game_duel_seats: { player_id: player.id }) if token.is_a?(String)
      duel ? Success(duel) : Failure(:duel_not_found)
    end

    def whole_number(value)
      number = value.is_a?(Integer) ? value : (Integer(value, 10, exception: false) if value.is_a?(String))
      number ? Success(number) : Failure(:invalid_move)
    end

    def known_stat(value) = named(DuelStat::STATS, value)

    def known_direction(value) = named(DuelStat::DIRECTIONS, value)

    def named(names, value)
      name = names.find { it.to_s == value.to_s } if value.is_a?(String) || value.is_a?(Symbol)
      name ? Success(name) : Failure(:invalid_move)
    end

    def lock_duel(duel)
      TradeLocks.players(*Accounts::Player.in_good_standing.where(id: DuelSeat.where(duel_id: duel.id).select(:player_id)).ids)
      locked = Duel.lock.find(duel.id)
      seats = DuelSeat.where(duel_id: duel.id).order(:id).lock.to_a
      [ locked, seats.index_by { it.role.to_sym } ]
    end

    def role_of(seats, player)
      role = seats.values.find { it.player_id == player.id }&.role
      role ? Success(role.to_sym) : Failure(:duel_not_found)
    end

    def friends_to_duel(player, other_id)
      current = Accounts::Player.where(id: [ player.id, other_id ]).index_by(&:id)
      other = current[other_id]
      return Failure(:not_a_friend) unless other && !other.removed? && FriendshipBetween.call(player, other)

      if !Visibility.open_to_friends?(current[player.id]) then Failure(:own_duels_closed)
      elsif !Visibility.open_to_friends?(other) then Failure(:friend_duels_closed)
      else Success()
      end
    end

    def reachable(player, friend)
      ReachableFriends.call(player).any? { it.player.id == friend.id } ? Success() : Failure(:friend_unavailable)
    end

    def ready_deck(player_id, token)
      deck = Deck.find_by(player_id:, token:) if token.is_a?(String)
      return Failure(:deck_not_ready) unless deck

      card_season_ids = DeckCard.where(deck_id: deck.id).pluck(:card_season_id)
      held = Holding.where(player_id:, card_season_id: card_season_ids).where("quantity > 0").count
      card_season_ids.size == Deck::SLOTS.size && held == card_season_ids.size ? Success(deck) : Failure(:deck_not_ready)
    end

    def seated?(player_id) = DuelSeat.exists?(player_id:, status: "seated")

    def busy?(player_id) = DuelSeat.exists?(player_id:, status: %w[seated invited])

    def not_seated(player) = seated?(player.id) ? Failure(:duel_in_progress) : Success()

    def idle(player) = busy?(player.id) ? Failure(:duel_in_progress) : Success()

    def free(friend) = busy?(friend.id) ? Failure(:friend_busy) : Success()

    def playing(duel, move_number)
      duel.state == "active" && duel.move_number == move_number
    end

    def card_in_hand(rules, role, position)
      card = rules.deck(role)[position - 1] if Deck::SLOTS.cover?(position)
      card && rules.hand(role).include?(card) ? Success(card) : Failure(:card_not_in_hand)
    end

    def snapshot_value(card, stat) = card.to_snapshot.dig("stats", stat.to_s, "value")

    def next_move(duel) = duel.move_number + 1

    def leave(seats)
      seats.each_value { it.update!(status: "left") }
    end

    def release_deleted(seats)
      deleted = Accounts::Player.where(id: seats.values.filter_map(&:player_id)).where.not(deleted_at: nil).ids
      seats.each_value { it.update!(player_id: nil) if deleted.include?(it.player_id) }
    end

    def end_challenge(state, event, player, duel, seats)
      return Failure(:not_your_move) unless duel.state == "challenged"

      duel.update!(state:, ended_at: Time.current, move_number: next_move(duel))
      close_seats(event, player, duel, seats)
    end

    def close_seats(event, player, duel, seats)
      leave(seats)
      published = duel_published(event, player, duel, seats)
      release_deleted(seats)
      published
    end

    def lapse(player, duel, seats) = end_challenge("lapsed", DuelChallengeLapsed, player, duel, seats)

    def challenger(seats, player) = seats[:challenger].player_id == player.id ? Success() : Failure(:not_your_move)

    def invited_friend(seats, player) = seats[:opponent].player_id == player.id ? Success() : Failure(:not_your_move)

    def schedule(duel, move_number, seconds)
      at = seconds.from_now
      DuelDeadlineJob.set(wait_until: at + DuelClock::JOB_DELAY).perform_later(duel.token, move_number)
      at
    end

    def due(state, duel, seats, move_number, rules = nil)
      current = duel.state == state && duel.move_number == move_number && DuelClock.new(duel, seats.values, rules).due?(Time.current)
      current ? Success() : Failure(:not_due)
    end

    def duel_published(event, player, duel, seats)
      data = { duel_id: duel.id, challenger_id: seats[:challenger].player_id, opponent_id: seats[:opponent].player_id }
      publish(event.new(data:), stream_name: stream_name(player.id))
    end

    def round_published(event, player, duel, number)
      publish(event.new(data: { duel_id: duel.id, number: }), stream_name: stream_name(player.id))
    end
  end
end
