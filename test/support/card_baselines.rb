require "vips"

# Screenshots of card faces compared with committed baselines
# (test/fixtures/files/card_faces/<name>.png): same dimensions, and a mean
# absolute difference of at most TOLERANCE per channel. With
# UPDATE_CARD_BASELINES=1 the baselines are written instead. On a mismatch
# the actual image and the difference are saved under tmp/screenshots/.
module CardBaselines
  DIRECTORY = Rails.root.join("test/fixtures/files/card_faces")
  TOLERANCE = 1.5

  # Waits until the face is still: fonts loaded, art settled, the tilt held
  # and no animation or transition left under it.
  def assert_card_settled(card)
    page.document.synchronize(10) do
      ready = card.evaluate_script(<<~JS)
        (() => {
          if (document.fonts.status !== "loaded") return false
          if (this.querySelector(".card__art:not([data-art])")) return false
          if (this.dataset.tilt !== "held") return false
          return this.getAnimations({ subtree: true }).length === 0
        })()
      JS
      raise Capybara::ExpectationNotMet, "the card is not settled" unless ready
    end
  end

  def assert_matches_card_baseline(element, name)
    png = element.native.screenshot_as(:png)
    path = DIRECTORY.join("#{name}.png")
    if ENV["UPDATE_CARD_BASELINES"].present?
      FileUtils.mkdir_p(DIRECTORY)
      File.binwrite(path, png)
      return
    end

    assert path.file?, "no baseline #{path.relative_path_from(Rails.root)}: run with UPDATE_CARD_BASELINES=1"
    actual = rgb(Vips::Image.new_from_buffer(png, ""))
    expected = rgb(Vips::Image.new_from_file(path.to_s))
    same_size = [ actual.width, actual.height ] == [ expected.width, expected.height ]
    difference = (actual - expected).abs if same_size
    means = difference ? (0...difference.bands).map { |band| difference.extract_band(band).avg } : []
    return pass if same_size && means.max <= TOLERANCE

    keep_failure(name, png, difference)
    flunk "#{name} differs from its baseline: " +
      (same_size ? "mean difference per channel #{means.map { it.round(2) }}" : "#{actual.width}×#{actual.height}, not #{expected.width}×#{expected.height}")
  end

  private
    def rgb(image)
      image = image.flatten(background: [ 0, 0, 0 ]) if image.has_alpha?
      image.bands > 3 ? image.extract_band(0, n: 3) : image
    end

    def keep_failure(name, png, difference)
      directory = Rails.root.join("tmp/screenshots")
      FileUtils.mkdir_p(directory)
      File.binwrite(directory.join("card-#{name}-actual.png"), png)
      (difference * 10).cast(:uchar).write_to_file(directory.join("card-#{name}-diff.png").to_s) if difference
    end
end
