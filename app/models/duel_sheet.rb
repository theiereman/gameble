class DuelSheet
  DeckChoice = Data.define(:token, :name, :count, :selected) do
    def draft? = count < Game::Deck::SLOTS.size
  end
  FriendChoice = Data.define(:player, :selected, :state)

  def initialize(lobby, decks:, friend_token: nil, gone_token: nil)
    @lobby = lobby
    @decks = decks
    @friend_token = friend_token
    @gone_token = gone_token
  end

  def deck_choices
    @deck_choices ||= begin
      complete, drafts = @decks.rows.partition(&:complete?)
      chosen = complete.find { it.token == Game::LastUsedDeck.call(@lobby.player) } || complete.first
      (complete + drafts).map { DeckChoice.new(token: it.token, name: it.name, count: it.count, selected: it.equal?(chosen)) }
    end
  end

  def complete_deck? = deck_choices.any? { !it.draft? }

  def friend_choices
    @friend_choices ||= begin
      rows = @lobby.reachable.map { FriendChoice.new(player: it.player, selected: false, state: it.in_duel ? :in_duel : :free) }
      rows = rows.map { it.player.token == @gone_token ? it.with(state: :gone) : it }
      rows << FriendChoice.new(player: gone_friend, selected: false, state: :gone) if gone_friend && rows.none? { it.state == :gone }
      free = rows.select { it.state == :free }
      chosen = free.find { it.player.token == @friend_token } || free.first
      rows.map { it.with(selected: it.equal?(chosen)) }
    end
  end

  def friend_open? = friend_choices.any? { it.state == :free }

  def open? = friend_choices.any? { it.state == :gone || it.player.token == @friend_token }

  def disabled_reason
    if @lobby.seated || @lobby.received then Game::ChallengeFriend.failure_message(:duel_in_progress)
    elsif @lobby.closed? then Game::ChallengeFriend.failure_message(:own_duels_closed)
    elsif !complete_deck? then I18n.t("duels.sheet.no_deck")
    elsif !friend_open? then I18n.t(@lobby.befriended? ? "duels.online.none" : "duels.online.no_friends")
    end
  end

  private
    def gone_friend
      return @gone_friend if defined?(@gone_friend)

      @gone_friend = @gone_token && Game::FriendsOf.call(@lobby.player).find { it.token == @gone_token }
    end
end
