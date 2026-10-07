# A button of DESIGN.md (Buttons): primary (lime, one per view), secondary
# (blue-grey), danger (deleting the account) or link (muted Space Mono text).
# Renders a link when given an href, a one-button form when given an href and
# a method (POST, DELETE…, with the CSRF token and any extra params), else a
# <button>. `disabled: true` always renders a plain disabled <button>: a
# disabled action is never a link or a form (its reason is written next to
# it). `size: :small` is the small height; `icon:` names a pixel icon
# (app/frontend/images/pixel/) shown before the label. `turbo: false` makes
# the form or link a full-page load, for a response that leaves the site
# (Steam sign-in) or the app's pages (the job queue). `confirm:` asks the
# browser to confirm a form button before it is sent (Turbo's
# data-turbo-confirm). `opens:` names a dialog by its id: the button opens it
# (dialog_opener_controller.ts), for a game-styled action that needs an
# account and opens the sign-in panel instead (DESIGN.md, Sign-in panel);
# without JavaScript it does nothing.
class ButtonComponent < ViewComponent::Base
  VARIANTS = %i[primary secondary danger link].freeze
  SIZES = %i[default small].freeze

  def initialize(variant: :primary, href: nil, type: :button, method: nil, params: {}, turbo: true, confirm: nil,
    size: :default, icon: nil, disabled: false, opens: nil)
    raise ArgumentError, "unknown button variant: #{variant.inspect}" unless VARIANTS.include?(variant)
    raise ArgumentError, "unknown button size: #{size.inspect}" unless SIZES.include?(size)
    raise ArgumentError, "a form button needs an href" if method && href.nil?
    raise ArgumentError, "only a form button can ask for confirmation" if confirm && method.nil?
    raise ArgumentError, "a dialog opener is a plain button" if opens && (href || disabled)

    @variant = variant
    @href = href
    @type = type
    @method = method
    @params = params
    @turbo = turbo
    @confirm = confirm
    @size = size
    @icon = icon
    @disabled = disabled
    @opens = opens
  end

  private
    def classes
      [ "button", "button--#{@variant}", ("button--small" if @size == :small) ].compact.join(" ")
    end

    def label
      return content unless @icon

      safe_join([ helpers.pixel_icon(@icon, class: "button__icon"), tag.span(content, class: "button__label") ])
    end

    # The attributes of a button opening a dialog (dialog_opener_controller.ts).
    def opener_options
      { aria: { haspopup: "dialog" },
        data: { controller: "dialog-opener", action: "dialog-opener#open", dialog_opener_dialog_value: @opens } }
    end

    def form_options
      data = {}
      data[:turbo] = false unless @turbo
      data[:turbo_confirm] = @confirm if @confirm
      data.empty? ? {} : { data: data }
    end
end
