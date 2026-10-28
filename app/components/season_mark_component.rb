class SeasonMarkComponent < ViewComponent::Base
  def self.label(season) = "S#{season}"

  def initialize(season:, **html_options)
    @season = Integer(season)
    @html_options = html_options
  end

  private
    def classes
      [ "season-mark", @html_options[:class] ].compact.join(" ")
    end
end
