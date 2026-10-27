class ButtonComponent < ViewComponent::Base
  VARIANTS = %i[primary secondary danger link].freeze
  SIZES = %i[default small].freeze

  def initialize(variant: :primary, href: nil, type: :button, method: nil, params: {}, turbo: true, confirm: nil,
    size: :default, icon: nil, disabled: false, opens: nil, aria_label: nil)
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
    @aria_label = aria_label
  end

  private
    def classes
      [ "button", "button--#{@variant}", ("button--small" if @size == :small) ].compact.join(" ")
    end

    def label
      return content unless @icon

      safe_join([ helpers.pixel_icon(@icon, class: "button__icon"), tag.span(content, class: "button__label") ])
    end

    def opener_options
      { aria: { haspopup: "dialog", label: @aria_label }.compact,
        data: { controller: "dialog-opener", action: "dialog-opener#open", dialog_opener_dialog_value: @opens } }
    end

    def aria_options
      @aria_label ? { aria: { label: @aria_label } } : {}
    end

    def form_options
      data = {}
      data[:turbo] = false unless @turbo
      data[:turbo_confirm] = @confirm if @confirm
      data.empty? ? {} : { data: data }
    end
end
