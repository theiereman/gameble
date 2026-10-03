require "test_helper"

# Absolute links handed out to the world (CAP-9, story 4.5): on the
# configured public base; on the request's own base outside production only.
class PublicUrlsHelperTest < ActionView::TestCase
  setup do
    # A PUBLIC_URL exported in the shell would replace the request's base.
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
  end

  teardown do
    Rails.configuration.x.public_url = @public_url
  end

  test "the configured base, whatever the request's host" do
    Rails.configuration.x.public_url = "https://gameble.example"
    request.host = "evil.example"

    assert_equal "https://gameble.example/en/brothers/x", public_url_for("/en/brothers/x")
  end

  test "without a configured base, the request's base outside production" do
    assert_equal "http://test.host/en", public_url_for("/en")
  end

  test "without a configured base, an error in production" do
    Rails.env = "production"

    assert_raises(PublicUrlsHelper::MissingPublicUrl) { public_url_for("/en") }
  ensure
    Rails.env = "test"
  end
end
