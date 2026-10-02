# Primary (rust) or secondary (parchment) button with a hard ink shadow (DESIGN.md: buttons).
# Renders a link when given an href, else a <button>.
class ButtonComponent < ViewComponent::Base
  VARIANTS = %i[primary secondary].freeze

  def initialize(variant: :primary, href: nil, type: :button)
    raise ArgumentError, "unknown button variant: #{variant.inspect}" unless VARIANTS.include?(variant)

    @variant = variant
    @href = href
    @type = type
  end

  private
    def classes
      "button button--#{@variant}"
    end
end
