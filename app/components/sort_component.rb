class SortComponent < ViewComponent::Base
  Option = Data.define(:label, :href, :current)

  def initialize(prefix:, label:, options:, link_data: {})
    @prefix = prefix
    @label = label
    @options = options.map { Option.new(current: false, **it) }
    @link_data = link_data
  end

  private
    attr_reader :prefix, :label, :options, :link_data

    def current_label = options.find(&:current)&.label || options.first&.label
end
