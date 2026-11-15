# What the deck editor draws: one entry per edition the player owns, by title then season, each with its trump or why it
# cannot enter the deck, and the deck's twelve slots.
class DeckEditor
  Entry = Data.define(:ref, :game, :title, :season_number, :image_url, :trump_stat, :availability) do
    def available? = availability == :available
  end

  attr_reader :deck

  def initialize(player, deck:, locale:)
    @player = player
    @deck = deck
    @locale = locale
  end

  def entries
    @entries ||= by_card_season.values.sort_by { [ it.title.downcase, it.season_number ] }
  end

  def slots
    Game::Deck::SLOTS.map { by_card_season[slotted[it]] }
  end

  def count = slotted.size

  def in_deck?(entry) = deck_refs.include?(entry.ref)

  private
    def held = @held ||= Game::HeldCopies.call(@player)

    def slotted = @slotted ||= Game::DeckSlots.call(@deck)

    def decked_elsewhere = @decked_elsewhere ||= Game::DeckedEditions.call(@player, except: @deck)

    def deck_refs = @deck_refs ||= slotted.values.filter_map { by_card_season[it]&.ref }.to_set

    def by_card_season
      @by_card_season ||= begin
        views = Catalog::CardViews.call(held.keys | slotted.values, locale: @locale)
        profiles = Game::DuelProfiles.call(views.keys)
        views.to_h { |card_season_id, view| [ card_season_id, entry(card_season_id, view, profiles[card_season_id]) ] }
      end
    end

    def entry(card_season_id, view, profile)
      Entry.new(ref: Game::Market::EntrustableCopies.ref(view.id, view.season_number), game: view.id, title: view.title,
        season_number: view.season_number, image_url: view.image_url, trump_stat: profile&.trump_stat, availability: availability(card_season_id, profile))
    end

    def availability(card_season_id, profile)
      if slotted.value?(card_season_id)
        :available
      elsif !profile&.ranked?
        :unranked
      elsif (held[card_season_id]&.free || 0) < 1 && !decked_elsewhere.include?(card_season_id)
        :reserved
      else
        :available
      end
    end
end
