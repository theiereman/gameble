class MarketRowComponent < ViewComponent::Base
  TONES = %i[accent lime orange gold muted].freeze

  renders_one :note
  renders_one :action

  # facts: [label, value] pairs drawn as labelled columns; rarities: an order's reached rarities, drawn as pills in place of the card's.
  def initialize(card:, href:, token:, status:, tone:, facts: [], rarities: nil, edition_note: nil)
    raise ArgumentError, "unknown market row tone: #{tone.inspect}" unless TONES.include?(tone)

    @card = card
    @href = href
    @token = token
    @status = status
    @tone = tone
    @facts = facts
    @rarities = rarities
    @edition_note = edition_note
  end

  private
    attr_reader :card, :href, :token, :status, :tone, :facts, :rarities, :edition_note

    def rarity_name = CardStrings.new.rarity_name(card.rarity)
end
