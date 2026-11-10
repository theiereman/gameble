class MarketRowComponent < ViewComponent::Base
  TONES = %i[accent lime orange gold muted].freeze

  renders_one :note
  renders_one :action

  # facts: [label, value] pairs drawn as labelled columns.
  def initialize(card:, href:, token:, status:, tone:, facts: [])
    raise ArgumentError, "unknown market row tone: #{tone.inspect}" unless TONES.include?(tone)

    @card = card
    @href = href
    @token = token
    @status = status
    @tone = tone
    @facts = facts
  end

  private
    attr_reader :card, :href, :token, :status, :tone, :facts

    def rarity_name = CardStrings.new.rarity_name(card.rarity)
end
