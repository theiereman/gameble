class SectionComponent < ViewComponent::Base
  renders_one :aside

  def initialize(title:, id:, **html_options)
    @title = title
    @id = id
    @html_options = html_options
  end

  private
    attr_reader :title, :id

    def classes = [ "section", @html_options[:class] ].compact.join(" ")

    def html_options = @html_options.except(:class)
end
