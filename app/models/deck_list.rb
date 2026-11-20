class DeckList
  Cover = Data.define(:image_url)

  Row = Data.define(:token, :name, :count, :covers) do
    def complete? = count == Game::Deck::SLOTS.size
  end

  def initialize(player, locale:)
    @player = player
    @locale = locale
  end

  def rows
    @rows ||= begin
      views = Catalog::CardViews.call(decks.flat_map { it.slots.values }, locale: @locale)
      decks.map { |deck| row(deck, views) }
    end
  end

  def count = decks.size

  def limit = @limit ||= Game::Capacity.limit(@player, :deck)

  def room_left? = count < limit

  private
    def decks = @decks ||= Game::PlayerDecks.listing(@player)

    def row(deck, views)
      covers = Game::Deck::SLOTS.map { |slot| views[deck.slots[slot]]&.image_url&.then { Cover.new(image_url: it) } }
      Row.new(token: deck.token, name: deck.name, count: deck.slots.size, covers:)
    end
end
