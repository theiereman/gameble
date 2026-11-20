class EmptyStateComponent < ViewComponent::Base
  renders_one :action

  def initialize(line:)
    @line = line
  end

  private
    attr_reader :line
end
