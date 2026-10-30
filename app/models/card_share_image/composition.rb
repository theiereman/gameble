require "vips"

module CardShareImage
  class Composition
    Box = Data.define(:x, :y, :width, :height)

    FONT_DIRECTORY = Rails.root.join("vendor/fonts")
    FONTS = {
      title: { family: "VT323", files: %w[vt323-latin-400-normal.ttf vt323-latin-ext-400-normal.ttf] },
      meta: { family: "JetBrains Mono Bold", files: %w[jetbrains-mono-latin-700-normal.ttf jetbrains-mono-latin-ext-700-normal.ttf] }
    }.freeze

    COLOURS = {
      ground: "#0b0f15", panel: "#121a24", panel_raised: "#1b2838", outline: "#06090d",
      text_max: "#ffffff", text_bright: "#e6eef5", muted: "#8f98a0", publisher: "#8a96a2"
    }.transform_values { |hex| hex.delete_prefix("#").scan(/../).map(&:hex) }.freeze
    RARITY_COLOURS = {
      "common" => "#8f98a0", "uncommon" => "#3fcf8e", "rare" => "#66c0f4", "epic" => "#b47cff", "legendary" => "#f4c542"
    }.transform_values { |hex| hex.delete_prefix("#").scan(/../).map(&:hex) }.freeze

    ART_PIXEL = 3
    CARD = Box.new(x: 96, y: 45, width: 360, height: 540)
    OUTLINE = 6
    FRAME = 9
    BEVEL = 4
    BODY = Box.new(x: CARD.x + FRAME, y: CARD.y + FRAME, width: CARD.width - 2 * FRAME, height: CARD.height - 2 * FRAME)
    INSIDE = Box.new(x: BODY.x + 7, y: BODY.y + 8, width: Art::WIDTH * ART_PIXEL, height: BODY.height - 15)
    GAP = 6
    BAND = Box.new(x: INSIDE.x, y: INSIDE.y, width: INSIDE.width, height: 90)
    TICK = 4
    BAND_PADDING = 9
    ART = Box.new(x: INSIDE.x, y: BAND.y + BAND.height + GAP, width: INSIDE.width, height: Art::HEIGHT * ART_PIXEL)
    LINE = Box.new(x: INSIDE.x, y: ART.y + ART.height + GAP, width: INSIDE.width, height: 27)
    RARITY_LINE = Box.new(x: INSIDE.x, y: LINE.y + LINE.height + GAP, width: INSIDE.width, height: 36)
    LINE_PADDING = 6
    BRACKET = { inset: 3, length: 12, thickness: 3 }.freeze
    CARD_ICON_PIXEL = 3
    COLUMN_ICON_PIXEL = 6

    COLUMN = Box.new(x: CARD.x + CARD.width + 80, y: CARD.y, width: WIDTH - (CARD.x + CARD.width + 80) - 72, height: CARD.height)
    COLUMN_TITLE_SIZES = [ 88, 76, 64, 54, 44 ].freeze
    COLUMN_TITLE_MAX_HEIGHT = 300

    # Pango markup refuses the control characters but tab and line breaks.
    MARKUP_INVALID = /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/

    def initialize(view, art)
      @view = view
      @art = art
    end

    def png
      canvas = Vips::Image.black(WIDTH, HEIGHT).new_from_image(COLOURS[:ground]).copy(interpretation: :srgb).cast(:uchar)
      canvas = draw_card_frame(canvas)
      canvas = canvas.insert(art.zoom(ART_PIXEL, ART_PIXEL), ART.x, ART.y)
      canvas = draw_art_brackets(canvas)
      canvas = draw_card_text(canvas)
      encode(draw_column(canvas))
    end

    private
      attr_reader :view, :art

      def encode(canvas)
        png = canvas.pngsave_buffer(compression: 9, strip: true)
        png.bytesize > MAX_BYTES ? canvas.pngsave_buffer(compression: 9, strip: true, palette: true) : png
      end

      def rarity_colour = RARITY_COLOURS.fetch(view.rarity.to_s)

      def strings = @strings ||= CardStrings.new

      def draw_card_frame(canvas)
        light, dark = [ 255, 0 ].map { |shade| rarity_colour.map { ((it * 0.65) + (shade * 0.35)).round } }
        canvas.mutate do |image|
          outline(image)
          fill(image, rarity_colour, CARD)
          fill(image, light, Box.new(x: CARD.x, y: CARD.y, width: CARD.width, height: BEVEL))
          fill(image, light, Box.new(x: CARD.x, y: CARD.y, width: BEVEL, height: CARD.height))
          fill(image, dark, Box.new(x: CARD.x, y: CARD.y + CARD.height - BEVEL, width: CARD.width, height: BEVEL))
          fill(image, dark, Box.new(x: CARD.x + CARD.width - BEVEL, y: CARD.y + BEVEL, width: BEVEL, height: CARD.height - BEVEL))
          fill(image, COLOURS[:panel], BODY)
          [ BAND, LINE, RARITY_LINE ].each { fill(image, COLOURS[:panel_raised], it) }
          fill(image, rarity_colour, Box.new(x: BAND.x, y: BAND.y, width: TICK, height: BAND.height))
        end
      end

      def outline(image)
        colour = COLOURS[:outline]
        fill(image, colour, Box.new(x: CARD.x, y: CARD.y - OUTLINE, width: CARD.width, height: OUTLINE))
        fill(image, colour, Box.new(x: CARD.x, y: CARD.y + CARD.height, width: CARD.width, height: OUTLINE))
        fill(image, colour, Box.new(x: CARD.x - OUTLINE, y: CARD.y, width: OUTLINE, height: CARD.height))
        fill(image, colour, Box.new(x: CARD.x + CARD.width, y: CARD.y, width: OUTLINE, height: CARD.height))
      end

      def fill(image, colour, box)
        image.draw_rect!(colour, box.x, box.y, box.width, box.height, fill: true)
      end

      def draw_art_brackets(canvas)
        inset, length, thickness = BRACKET.values_at(:inset, :length, :thickness)
        white = COLOURS[:text_max]
        top_left = [ ART.x + inset, ART.y + inset ]
        bottom_right = [ ART.x + ART.width - inset, ART.y + ART.height - inset ]
        canvas.mutate do |image|
          fill(image, white, Box.new(x: top_left[0], y: top_left[1], width: length, height: thickness))
          fill(image, white, Box.new(x: top_left[0], y: top_left[1], width: thickness, height: length))
          fill(image, white, Box.new(x: bottom_right[0] - length, y: bottom_right[1] - thickness, width: length, height: thickness))
          fill(image, white, Box.new(x: bottom_right[0] - thickness, y: bottom_right[1] - length, width: thickness, height: length))
        end
      end

      def draw_card_text(canvas)
        canvas = draw_band(canvas)
        genre = view.genre && SetLabel.genre(view.genre)
        canvas = draw_line(canvas, LINE, genre&.upcase, view.year.to_s, size: 16)
        icon_size = icon&.size(CARD_ICON_PIXEL) || 0
        canvas = draw_icon(canvas, RARITY_LINE.x + LINE_PADDING, RARITY_LINE.y + ((RARITY_LINE.height - icon_size) / 2), pixel: CARD_ICON_PIXEL)
        left = icon ? LINE_PADDING + icon_size + LINE_PADDING : LINE_PADDING
        draw_line(canvas, RARITY_LINE, strings.rarity_name(view.rarity).upcase, number_label(with_season: true), size: 16, left:)
      end

      def draw_band(canvas)
        x = BAND.x + TICK + BAND_PADDING
        width = BAND.width - TICK - (2 * BAND_PADDING)
        title = text(view.title.upcase, :title, 33, width:, max_height: 60)
        publisher = view.publisher.presence && text(view.publisher, :meta, 18, width:, single_line: true)
        height = title.height + (publisher ? publisher.height + 4 : 0)
        y = BAND.y + ((BAND.height - height) / 2)
        canvas = paint(canvas, title, COLOURS[:text_max], x, y)
        publisher ? paint(canvas, publisher, COLOURS[:publisher], x, y + title.height + 4) : canvas
      end

      def draw_line(canvas, box, left_text, right_text, size:, left: LINE_PADDING)
        right = right_text.presence && text(right_text, :meta, size)
        right_x = box.x + box.width - LINE_PADDING - (right&.width || 0)
        if right
          canvas = paint(canvas, right, COLOURS[:muted], right_x, box.y + ((box.height - right.height) / 2))
        end
        return canvas if left_text.blank?

        mask = text(left_text, :meta, size, width: right_x - box.x - left - LINE_PADDING, single_line: true)
        paint(canvas, mask, rarity_colour, box.x + left, box.y + ((box.height - mask.height) / 2))
      end

      def draw_column(canvas)
        title = column_title
        rarity = text(strings.rarity_name(view.rarity).upcase, :meta, 36)
        icon_size = icon&.size(COLUMN_ICON_PIXEL) || 0
        number = number_label(with_season: true).presence && text(number_label(with_season: true), :meta, 28)
        rarity_height = [ rarity.height, icon_size ].max
        height = title.height + 32 + rarity_height + (number ? 20 + number.height : 0)
        y = COLUMN.y + ((COLUMN.height - height) / 2)
        canvas = paint(canvas, title, COLOURS[:text_bright], COLUMN.x, y)
        y += title.height + 32
        x = COLUMN.x
        if icon
          canvas = draw_icon(canvas, x, y + ((rarity_height - icon_size) / 2), pixel: COLUMN_ICON_PIXEL)
          x += icon_size + 16
        end
        canvas = paint(canvas, rarity, rarity_colour, x, y + ((rarity_height - rarity.height) / 2))
        number ? paint(canvas, number, COLOURS[:muted], COLUMN.x, y + rarity_height + 20) : canvas
      end

      def column_title
        COLUMN_TITLE_SIZES.each do |size|
          mask = text(view.title, :title, size, width: COLUMN.width)
          return mask if mask.height <= COLUMN_TITLE_MAX_HEIGHT
        end
        text(view.title, :title, COLUMN_TITLE_SIZES.last, width: COLUMN.width, max_height: COLUMN_TITLE_MAX_HEIGHT)
      end

      def number_label(with_season:)
        view.number ? view.number_label(with_season:) : ""
      end

      def text(string, font, size, width: nil, max_height: nil, single_line: false)
        family, files = FONTS.fetch(font).values_at(:family, :files)
        register_fonts
        options = { font: "#{family} #{size}", fontfile: FONT_DIRECTORY.join(files.first).to_s, dpi: 72 }
        options.merge!(width:, wrap: :word_char) if width && !single_line
        mask = Vips::Image.text(ERB::Util.html_escape(string.gsub(MARKUP_INVALID, "")), **options)
        mask = mask.crop(0, 0, [ mask.width, width ].min, mask.height) if width && single_line
        mask = mask.crop(0, 0, mask.width, [ mask.height, max_height ].min) if max_height
        mask
      end

      # libvips' text takes one font file a call and keeps each for the process: every subset is loaded before laying out.
      def register_fonts
        @fonts_registered ||= FONTS.each_value.flat_map { it[:files] }.each do |file|
          Vips::Image.text(".", fontfile: FONT_DIRECTORY.join(file).to_s, dpi: 72)
        end
      end

      def paint(canvas, mask, colour, x, y)
        mask = mask.crop(0, 0, [ mask.width, WIDTH - x ].min, [ mask.height, HEIGHT - y ].min)
        region = canvas.crop(x, y, mask.width, mask.height)
        canvas.insert(mask.ifthenelse(colour, region, blend: true), x, y)
      end

      def icon = defined?(@icon) ? @icon : (@icon = RarityIcon.of(view.rarity))

      def draw_icon(canvas, x, y, pixel:)
        return canvas if icon.nil?

        canvas.mutate { icon.draw(it, x, y, pixel:) }
      end
  end
end
