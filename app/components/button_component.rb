# Primary (rust) or secondary (parchment) button with a hard ink shadow (DESIGN.md: buttons).
# Renders a link when given an href, a one-button form when given an href and
# a method (POST, DELETE…, with the CSRF token and any extra params), else a
# <button>. `turbo: false` makes the form a full-page submission, for a form
# whose response leaves the site (Steam sign-in).
class ButtonComponent < ViewComponent::Base
  VARIANTS = %i[primary secondary].freeze

  def initialize(variant: :primary, href: nil, type: :button, method: nil, params: {}, turbo: true)
    raise ArgumentError, "unknown button variant: #{variant.inspect}" unless VARIANTS.include?(variant)
    raise ArgumentError, "a form button needs an href" if method && href.nil?

    @variant = variant
    @href = href
    @type = type
    @method = method
    @params = params
    @turbo = turbo
  end

  private
    def classes
      "button button--#{@variant}"
    end

    def form_options
      @turbo ? {} : { data: { turbo: false } }
    end
end
