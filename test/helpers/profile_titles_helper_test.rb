require "test_helper"

class ProfileTitlesHelperTest < ActionView::TestCase
  def title(rank, kind: "studio", params: { "studio" => "Valve" })
    Game::ProfileTitles::Title.new(kind:, key: "valve", params:, rank:, season_number: 1)
  end

  test "a title names its rank and its set in English" do
    I18n.with_locale(:en) do
      assert_equal "Adept · Valve", profile_title_text(title("adept"))
      assert_equal "Completionist · Valve", profile_title_text(title("complete"))
    end
  end

  test "a title names its rank and its set in French" do
    I18n.with_locale(:fr) do
      assert_equal "Adepte · Valve", profile_title_text(title("adept"))
      assert_equal "Maître · Valve", profile_title_text(title("master"))
      assert_equal "Complétiste · Valve", profile_title_text(title("complete"))
    end
  end
end
