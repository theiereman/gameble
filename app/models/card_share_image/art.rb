require "faraday"
require "vips"

module CardShareImage
  class Art
    class Unusable < StandardError; end

    WIDTH = CardComponent::PALETTE.fetch(:width)
    HEIGHT = CardComponent::PALETTE.fetch(:height)
    COLOURS = 32
    ANCHOR = 0.42

    # Steam answers a missing cover with a grey 300 × 450 placeholder.
    MIN_WIDTH = 300
    MIN_HEIGHT = 450
    MAX_SIDE = 4_096
    MAX_BYTES = 8.megabytes
    GREY_CHANNEL_TOLERANCE = 2
    GREY_TONE_RANGE = 24

    LOADERS = %w[jpegload_buffer pngload_buffer webpload_buffer].freeze

    class_attribute :adapter, default: [ Faraday.default_adapter ]

    def self.steam_image?(url)
      uri = URI.parse(url.to_s)
      Steam::Cdn::IMAGE_SOURCES.any? do |source|
        scheme, host = source.split("://", 2)
        uri.scheme == scheme && uri.host.present? && host_matches?(uri.host, host)
      end
    rescue URI::InvalidURIError
      false
    end

    def self.host_matches?(host, pattern)
      pattern.start_with?("*.") ? host.end_with?(pattern.delete_prefix("*")) : host == pattern
    end
    private_class_method :host_matches?

    def initialize(url)
      @url = url
    end

    def pixels
      image = decode(download)
      refuse("is smaller than #{MIN_WIDTH} × #{MIN_HEIGHT}") if image.width < MIN_WIDTH || image.height < MIN_HEIGHT
      art = cropped(opaque(image)).thumbnail_image(WIDTH, height: HEIGHT, size: :force).copy_memory
      refuse("is Steam's grey placeholder") if flat_grey?(art)

      quantised(art)
    end

    private
      attr_reader :url

      def refuse(reason)
        raise Unusable, "the art at #{url} #{reason}"
      end

      def download
        refuse("is not on Steam's image hosts") unless self.class.steam_image?(url)

        response = connection.get(url)
        refuse("answered #{response.status}") unless response.status == 200
        body = response.body.to_s
        refuse("is over #{MAX_BYTES} bytes") if body.bytesize > MAX_BYTES
        body
      rescue Faraday::Error => error
        refuse("could not be fetched: #{error.class}")
      end

      def connection
        Faraday.new(request: { timeout: 15, open_timeout: 5 }) { it.adapter(*adapter) }
      end

      def decode(body)
        image = Vips::Image.new_from_buffer(body, "")
        refuse("is not a JPEG, PNG or WebP") unless LOADERS.include?(image.get("vips-loader"))
        refuse("is over #{MAX_SIDE} pixels a side") if [ image.width, image.height ].max > MAX_SIDE
        image
      rescue Vips::Error
        refuse("could not be decoded")
      end

      def opaque(image)
        image = image.colourspace(:srgb) unless image.interpretation == :srgb
        image = image.flatten if image.has_alpha?
        image.extract_band(0, n: 3).cast(:uchar)
      end

      def flat_grey?(image)
        red, green, blue = image.bandsplit
        spread = [ (red - green).abs.max, (green - blue).abs.max, (red - blue).abs.max ].max
        spread <= GREY_CHANNEL_TOLERANCE && image.max - image.min <= GREY_TONE_RANGE
      end

      def cropped(image)
        ratio = WIDTH.fdiv(HEIGHT)
        if image.width.fdiv(image.height) > ratio
          width = (image.height * ratio).round
          image.crop(((image.width - width) / 2.0).round, 0, width, image.height)
        else
          height = (image.width / ratio).round
          image.crop(0, ((image.height - height) * ANCHOR).round, image.width, height)
        end
      end

      # libvips quantises only through a palette writer; without one the art keeps its plain pixels.
      def quantised(image)
        Vips::Image.gifload_buffer(image.gifsave_buffer(bitdepth: Math.log2(COLOURS).to_i, dither: 0)).extract_band(0, n: 3)
      rescue Vips::Error
        image
      end
  end
end
