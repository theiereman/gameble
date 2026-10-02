# Primary (rust) or secondary (parchment) button with a hard ink shadow (DESIGN.md: buttons).
# Renders a link when given an href, a one-button form when given an href and
# a method (POST, DELETE…, with the CSRF token and any extra params), else a
# <button>. `turbo: false` makes the form or link a full-page load, for a
# response that leaves the site (Steam sign-in) or the app's pages (the
# job queue). `confirm:` asks the browser to confirm a form button before it
# is sent (Turbo's data-turbo-confirm).
class ButtonComponent < ViewComponent::Base
  VARIANTS = %i[primary secondary].freeze

  def initialize(variant: :primary, href: nil, type: :button, method: nil, params: {}, turbo: true, confirm: nil)
    raise ArgumentError, "unknown button variant: #{variant.inspect}" unless VARIANTS.include?(variant)
    raise ArgumentError, "a form button needs an href" if method && href.nil?
    raise ArgumentError, "only a form button can ask for confirmation" if confirm && method.nil?

    @variant = variant
    @href = href
    @type = type
    @method = method
    @params = params
    @turbo = turbo
    @confirm = confirm
  end

  private
    def classes
      "button button--#{@variant}"
    end

    def form_options
      data = {}
      data[:turbo] = false unless @turbo
      data[:turbo_confirm] = @confirm if @confirm
      data.empty? ? {} : { data: data }
    end
end
