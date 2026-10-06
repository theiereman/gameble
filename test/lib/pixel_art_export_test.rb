require "test_helper"
require "open3"
require "tmpdir"
require "zlib"

# The exported pixel art (AD-27, stories 8.1 and 8.8): the files under
# app/frontend/images/pixel/ are exactly what script/pixel_art/export.mjs
# writes, so an icon, a card back, the canister, the planet or an avatar is
# changed in the script, never by hand.
class PixelArtExportTest < ActiveSupport::TestCase
  PIXEL_DIR = Rails.root.join("app/frontend/images/pixel")
  BACK_NAMES = %w[standard saison-1 semaine-38 etoile-dor aurore millesime-2017 centurion soldes-hiver].freeze
  # Half of each DESIGN.md card size: one art pixel is 2 CSS px.
  BACK_SIZES = { "xs" => [ 50, 75 ], "s" => [ 56, 84 ], "m" => [ 80, 120 ], "l" => [ 104, 156 ], "xl" => [ 120, 180 ] }.freeze
  AVATAR_COLOURS = %w[blue pink gold jade orange lavender grey violet].freeze
  # Every committed file is one the script writes.
  FILE_COUNT = Dir.children(PIXEL_DIR).count

  test "the committed pixel art matches the export script" do
    output, status = export("--check")

    assert_predicate status, :success?, output
  end

  test "the export writes every committed file" do
    Dir.mktmpdir do |dir|
      output, status = export("--out", dir)

      assert_predicate status, :success?, output
      assert_equal Dir.children(PIXEL_DIR).sort, Dir.children(dir).sort
      assert_match(/#{FILE_COUNT} pixel-art files/, output)
    end
  end

  test "a second export changes no file, not even its modification time" do
    Dir.mktmpdir do |dir|
      export("--out", dir)
      before = snapshot(dir)

      output, status = export("--out", dir)

      assert_predicate status, :success?, output
      assert_equal before, snapshot(dir)
    end
  end

  test "the check passes right after an export" do
    Dir.mktmpdir do |dir|
      export("--out", dir)

      output, status = export("--check", "--out", dir)

      assert_predicate status, :success?, output
      assert_match(/#{FILE_COUNT} pixel-art files up to date/, output)
    end
  end

  test "the check fails and names a PNG whose pixels changed" do
    Dir.mktmpdir do |dir|
      export("--out", dir)
      change_first_pixel(File.join(dir, "planet.png"))

      output, status = export("--check", "--out", dir)

      assert_not_predicate status, :success?
      assert_match(/differs: .*planet\.png/, output)
    end
  end

  test "the check fails and names a missing file" do
    Dir.mktmpdir do |dir|
      export("--out", dir)
      File.delete(File.join(dir, "back-aurore-m.png"))

      output, status = export("--check", "--out", dir)

      assert_not_predicate status, :success?
      assert_match(/differs: .*back-aurore-m\.png/, output)
    end
  end

  test "the check fails and names a stray file" do
    Dir.mktmpdir do |dir|
      export("--out", dir)
      File.write(File.join(dir, "stray.png"), "")

      output, status = export("--check", "--out", dir)

      assert_not_predicate status, :success?
      assert_match(/not exported: .*stray\.png/, output)
    end
  end

  test "the review sheet holds every exported file and makes no request" do
    Dir.mktmpdir do |dir|
      export("--out", dir)
      sheet = File.join(dir, "sheet.html")

      output, status = export("--sheet", sheet, "--out", dir)

      assert_predicate status, :success?, output
      html = File.read(sheet)
      Dir.children(dir).without("sheet.html").each { |file| assert_includes html, file }
      assert_no_match(/http/, html)
    end
  end

  test "the review sheet needs a path" do
    output, status = export("--sheet")

    assert_not_predicate status, :success?
    assert_match(/usage/, output)
  end

  test "the committed PNGs have their art sizes" do
    BACK_NAMES.product(BACK_SIZES.to_a).each do |name, (size, dimensions)|
      assert_equal dimensions, png_size("back-#{name}-#{size}.png"), "back-#{name}-#{size}.png"
    end
    caps = %w[canister-cap-top.png canister-body.png canister-cap-bottom.png].map { |file| png_size(file) }
    assert_equal [ 100 ], caps.map(&:first).uniq
    assert_equal 150, caps.sum(&:last)
    assert_equal [ 200, 200 ], png_size("planet.png")
    AVATAR_COLOURS.each { |colour| assert_equal [ 16, 16 ], png_size("avatar-#{colour}.png"), colour }
  end

  private

  def export(*args)
    Open3.capture2e("node", "script/pixel_art/export.mjs", *args, chdir: Rails.root.to_s)
  end

  def snapshot(dir)
    Dir.children(dir).sort.to_h do |file|
      path = File.join(dir, file)
      [ file, [ File.binread(path), File.mtime(path).to_r ] ]
    end
  end

  # [width, height] from a PNG's IHDR chunk, right after the 8-byte signature
  # and the chunk's length and type.
  def png_size(file)
    File.binread(PIXEL_DIR.join(file), 24, 16).unpack("NN")
  end

  # Re-encodes the PNG with its first pixel's red channel flipped, as an
  # outside tool would: another zlib, the same filter-0 rows.
  def change_first_pixel(path)
    bytes = File.binread(path)
    width, height = bytes.byteslice(16, 8).unpack("NN")
    idat = String.new
    position = 8
    while position < bytes.bytesize
      length, type = bytes.byteslice(position, 8).unpack("Na4")
      idat << bytes.byteslice(position + 8, length) if type == "IDAT"
      position += 12 + length
    end
    rows = Zlib::Inflate.inflate(idat).bytes
    assert_equal (width * 4 + 1) * height, rows.size
    rows[1] ^= 0xff
    File.binwrite(path, bytes.byteslice(0, 33) + png_chunk("IDAT", Zlib::Deflate.deflate(rows.pack("C*"))) + png_chunk("IEND", ""))
  end

  def png_chunk(type, data)
    [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
  end
end
