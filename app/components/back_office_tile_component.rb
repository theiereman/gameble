class BackOfficeTileComponent < ViewComponent::Base
  def initialize(tile:)
    @tile = tile
  end

  private
    attr_reader :tile

    def classes
      class_names("office-tile", "office-tile--urgent": tile.status&.urgent)
    end

    def icon
      "office-#{tile.key.to_s.dasherize}"
    end

    def text(part)
      t("back_office.dashboard.show.tiles.#{tile.key}.#{part}")
    end
end
