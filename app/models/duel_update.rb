class DuelUpdate
  Closing = Data.define(:kind, :other)
  Outcome = Data.define(:kind, :other, :token)

  def initialize(player, notices)
    @player = player
    @notices = notices.select { it[:duel_id] }
  end

  def received? = @notices.any? { it[:role] == "opponent" }

  def closings
    ended("opponent", %w[cancelled lapsed]).map { |kind, duel| Closing.new(kind:, other: player_at(duel, "challenger")) }
  end

  def outcome
    kind, duel = ended("challenger", %w[accepted refused lapsed]).last
    return unless kind

    other = player_at(duel, "opponent")
    Outcome.new(kind: kind == "refused" && !complete_deck?(other) ? "no_deck" : kind, other:, token: duel.token)
  end

  private
    def ended(role, kinds)
      @notices.filter_map do |notice|
        duel = duels[notice[:duel_id]]
        [ notice[:kind], duel ] if duel && notice[:role] == role && kinds.include?(notice[:kind])
      end
    end

    def duels = @duels ||= Game::DuelsById.call(@notices.pluck(:duel_id)).index_by(&:id)

    def player_at(duel, role)
      player_id = duel.seats.find { it.role == role }&.player_id
      player_id && Accounts::PlayerById.call(player_id)
    end

    def complete_deck?(player)
      player.present? && Game::PlayerDecks.listing(player).any? { it.slots.size == Game::Deck::SLOTS.size }
    end
end
