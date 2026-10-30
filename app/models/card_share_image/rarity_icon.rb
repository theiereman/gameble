module CardShareImage
  # libvips' own SVG loader is blocked as untrusted: the icon is drawn from the SVG's runs.
  class RarityIcon
    PATH = /<path fill="#(\h{6})" d="([^"]+)"/
    RUN = /M(\d+) (\d+)h(\d+)v(\d+)h-\d+z/
    GRID = /viewBox="0 0 (\d+) \d+"/

    Run = Data.define(:colour, :x, :y, :width, :height)

    def self.of(rarity)
      tier = Catalog::Rarity::TIERS.invert.fetch(rarity.to_sym)
      icon = new(ShellHelper.pixel_source("rarity-#{tier}"))
      icon if icon.runs.any?
    end

    attr_reader :runs

    def initialize(source)
      @grid = source[GRID, 1].to_i
      @runs = source.scan(PATH).flat_map do |hex, path|
        colour = hex.scan(/../).map(&:hex)
        path.scan(RUN).map { |x, y, width, height| Run.new(colour, x.to_i, y.to_i, width.to_i, height.to_i) }
      end
    end

    def size(pixel) = @grid * pixel

    def draw(image, x, y, pixel:)
      runs.each do |run|
        image.draw_rect!(run.colour, x + (run.x * pixel), y + (run.y * pixel), run.width * pixel, run.height * pixel, fill: true)
      end
    end
  end
end
