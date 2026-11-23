# Two or three exclusive choices side by side, as one native radio group; `vertical_on_phone` stacks them as full-width rows on a phone.
class SegmentedComponent < ViewComponent::Base
  Option = Data.define(:value, :label, :amount, :accessible, :describedby, :checked, :disabled, :data) do
    def initialize(value:, label:, amount: nil, accessible: nil, describedby: nil, checked: false, disabled: false, data: {}) = super
  end

  def initialize(name:, label:, options:, describedby: nil, vertical_on_phone: false, **html_options)
    @name = name
    @label = label
    @options = options.map { Option.new(**it) }
    @describedby = describedby
    @vertical_on_phone = vertical_on_phone
    @html_options = html_options
  end

  private
    attr_reader :name, :label, :options, :describedby

    def classes = [ "segmented", ("segmented--vertical-on-phone" if @vertical_on_phone), @html_options[:class] ].compact.join(" ")

    def html_options = @html_options.except(:class)
end
