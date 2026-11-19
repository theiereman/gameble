class BrotherhoodCardComponent < ViewComponent::Base
  def initialize(card:, found:, pioneer:, viewer:, context: {}, strings: CardStrings.new)
    @card = card
    @found = found
    @pioneer = pioneer&.player
    @viewer = viewer
    @context = context
    @strings = strings
  end

  private
    attr_reader :card, :found, :pioneer, :viewer, :context

    def mine? = found && viewer.present? && pioneer&.id == viewer.id

    def path = helpers.card_detail_path(card.id, card.season_number, context)

    def accessible_name
      [ card.title, card.publisher.presence, card.year, @strings.rarity_name(card.rarity), discovery_words ].compact.join(", ")
    end

    def discovery_words
      return t("components.brotherhood_card.undiscovered_words") unless found
      return t("components.brotherhood_card.found_by_you") if mine?

      t("components.brotherhood_card.found_by", name: pioneer_name)
    end

    def pioneer_name
      return t("components.brotherhood_card.anonymous") if pioneer.nil? || pioneer.removed?

      Accounts::PersonaName.clean(pioneer.persona_name) || t("shell.player.fallback_name")
    end
end
