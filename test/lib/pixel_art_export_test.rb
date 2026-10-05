require "test_helper"
require "open3"

# The exported pixel art (AD-27, story 8.1): the files under
# app/frontend/images/pixel/ are exactly what script/pixel_art/export.mjs
# writes, so an icon is changed in the script, never by hand.
class PixelArtExportTest < ActiveSupport::TestCase
  test "the committed pixel art matches the export script" do
    output, status = Open3.capture2e("node", "script/pixel_art/export.mjs", "--check", chdir: Rails.root.to_s)

    assert_predicate status, :success?, output
  end
end
