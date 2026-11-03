require "test_helper"
require "open3"
require "tmpdir"

# The feed reaction icons: the files under app/frontend/images/reactions/
# are exactly what script/reaction_icons/export.mjs writes from its vector
# sources, so an icon is changed in its source, never by hand.
class ReactionIconsExportTest < ActiveSupport::TestCase
  ICON_DIR = Rails.root.join("app/frontend/images/reactions")

  test "the committed reaction icons match the export script" do
    output, status = export("--check")

    assert_predicate status, :success?, output
  end

  test "the export writes every committed file" do
    Dir.mktmpdir do |dir|
      output, status = export("--out", dir)

      assert_predicate status, :success?, output
      assert_equal Dir.children(ICON_DIR).sort, Dir.children(dir).sort
      assert_match(/5 reaction icons/, output)
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

  test "the check fails and names a missing file" do
    Dir.mktmpdir do |dir|
      export("--out", dir)
      File.delete(File.join(dir, "heart.png"))

      output, status = export("--check", "--out", dir)

      assert_not_predicate status, :success?
      assert_match(/differs: .*heart\.png/, output)
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

  test "each feed reaction has its icon, 20 × 20" do
    Game::FeedReaction::KINDS.each do |kind|
      assert_equal [ 20, 20 ], png_size("#{kind.dasherize}.png"), kind
    end
    assert_equal Game::FeedReaction::KINDS.size, Dir.children(ICON_DIR).size
  end

  private

  def export(*args)
    Open3.capture2e("node", "script/reaction_icons/export.mjs", *args, chdir: Rails.root.to_s)
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
    File.binread(ICON_DIR.join(file), 24, 16).unpack("NN")
  end
end
