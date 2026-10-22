require "test_helper"

class SearchTagsHelperTest < ActionView::TestCase
  include PublicUrlsHelper

  setup do
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
  end

  teardown { Rails.configuration.x.public_url = @public_url }

  test "og_locale names each served locale as Open Graph does" do
    assert_equal "en_US", I18n.with_locale(:en) { og_locale }
    assert_equal "fr_FR", I18n.with_locale(:fr) { og_locale }
  end

  test "every served locale has an Open Graph name, so one cannot be added without it" do
    assert_equal I18n.available_locales.map(&:to_s).sort, SearchTagsHelper::OG_LOCALES.keys.sort
  end

  test "a locale without an Open Graph name keeps its own code" do
    assert_equal "de", og_locale_for("de")
  end

  test "a route has an address in every served locale, and the page's own is the current one" do
    assert_equal({ "en" => "http://test.host/en", "fr" => "http://test.host/fr" }, language_alternates(:home_path))
    assert_equal "http://test.host/fr", I18n.with_locale(:fr) { current_language_url(:home_path) }
  end
end
