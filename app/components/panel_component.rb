class PanelComponent < ViewComponent::Base
  def initialize(tag: :div, quiet: false, brackets: false, **html_options)
    @tag = tag
    @quiet = quiet
    @brackets = brackets
    @html_options = html_options
  end

  private
    def classes
      [ "panel", ("panel--quiet" if @quiet), ("panel--brackets" if @brackets), @html_options[:class] ].compact.join(" ")
    end

    def html_options
      @html_options.except(:class)
    end
end
