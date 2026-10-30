require "vips"

# Stubs the fetch of a card's Steam art with Faraday's test adapter, and
# makes the covers and PNGs the share image tests need. Call
# `stub_share_image_art` in setup and `unstub_share_image_art` in teardown.
module ShareImageArt
  STEAM_ART = "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/403/library_600x900.jpg".freeze

  attr_reader :art_stubs

  def stub_share_image_art
    @art_adapter_was = CardShareImage::Art.adapter
    @art_stubs = Faraday::Adapter::Test::Stubs.new
    CardShareImage::Art.adapter = [ :test, @art_stubs ]
  end

  def unstub_share_image_art
    CardShareImage::Art.adapter = @art_adapter_was
  end

  def stub_art(url = STEAM_ART, body: cover_jpeg, status: 200)
    art_stubs.get(url) { [ status, { "Content-Type" => "image/jpeg" }, body ] }
  end

  # A colourful cover, as Steam's 600 × 900 library capsules.
  def cover_jpeg(width: 600, height: 900)
    xy = Vips::Image.xyz(width, height)
    red = xy[0] * 255 / width
    green = xy[1] * 255 / height
    blue = (xy[0] + xy[1]) % 255
    red.bandjoin([ green, blue ]).cast(:uchar).copy(interpretation: :srgb).jpegsave_buffer(Q: 90)
  end

  # A cover of colour noise, the busiest art a card can show.
  def noisy_cover_jpeg(width: 600, height: 900)
    bands = Array.new(3) { Vips::Image.gaussnoise(width, height, mean: 128, sigma: 90) }
    bands.first.bandjoin(bands.drop(1)).cast(:uchar).copy(interpretation: :srgb).jpegsave_buffer(Q: 95)
  end

  def png_colour_type(png) = png.getbyte(25)

  # Steam's answer for a missing cover: grey, 300 × 450, with JPEG noise wider than a pixel's channel tolerance.
  def grey_placeholder_jpeg
    noise = Vips::Image.gaussnoise(300, 450, mean: 142, sigma: 4)
    noise.bandjoin([ noise, noise ]).cast(:uchar).copy(interpretation: :srgb).jpegsave_buffer(Q: 75)
  end

  def tiny_png(width: 4, height: 4)
    Vips::Image.black(width, height).new_from_image([ 10, 20, 30 ]).cast(:uchar).copy(interpretation: :srgb).pngsave_buffer
  end

  def png_size(png)
    image = Vips::Image.new_from_buffer(png, "")
    [ image.get("vips-loader"), image.width, image.height ]
  end

  def use_steam_art(card_season_id, url = STEAM_ART)
    Catalog::Card.joins(:card_seasons).where(catalog_card_seasons: { id: card_season_id }).update_all(image_url: url)
  end

  def current_fingerprint(card_season_id, locale)
    CardShareImage.fingerprint(Catalog::CardViews.call([ card_season_id ], locale:).fetch(card_season_id), locale)
  end

  # Stores an image for the card-season as the render job would, with its current fingerprint unless one is given.
  def store_share_image(card_season_id, locale, fingerprint: current_fingerprint(card_season_id, locale), png: tiny_png)
    Catalog::StoreShareImage.new.call(card_season_id:, locale:, fingerprint:, png:, width: 4, height: 4,
      current_fingerprint: -> { fingerprint }).value!
  end
end
