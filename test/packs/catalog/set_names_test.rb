require "test_helper"

# Catalog::SetNames: the names, forms and keys of franchise and studio sets,
# and whether a title matches a franchise's name.
class Catalog::SetNamesTest < ActiveSupport::TestCase
  test "a franchise's name drops its marks and a trailing Franchise, Series or - Official, whatever the case" do
    assert_equal "Tom Clancy", Catalog::SetNames.franchise("Tom Clancy Franchise")
    assert_equal "Final Fantasy", Catalog::SetNames.franchise("Final Fantasy SERIES")
    assert_equal "Warhammer 40,000", Catalog::SetNames.franchise("Warhammer 40,000™ - Official")
    assert_equal "Series of Unfortunate Events", Catalog::SetNames.franchise("Series of Unfortunate Events")
  end

  test "a name's form is its words: case, punctuation and apostrophes ignored" do
    assert_equal "assassins creed", Catalog::SetNames.form("Assassin's Creed®")
    assert_equal "watch dogs", Catalog::SetNames.form("Watch_Dogs")
    assert_equal "", Catalog::SetNames.form("™ !")
  end

  test "names differing only by punctuation inside a word share a merge form" do
    [ [ "Watch_Dogs", "WatchDogs" ], [ "S.T.A.L.K.E.R.", "STALKER" ], [ "Yu-Gi-Oh!", "YuGiOh" ] ].each do |name, other|
      assert_equal Catalog::SetNames.merge_form(name), Catalog::SetNames.merge_form(other), name
    end
  end

  test "a company's name drops its marks, a platform in brackets and its trailing legal suffixes, keeping its case" do
    assert_equal "CAPCOM", Catalog::SetNames.company("CAPCOM Co., Ltd.")
    assert_equal "Feral Interactive", Catalog::SetNames.company("Feral Interactive (Mac)")
    assert_equal "Aspyr", Catalog::SetNames.company("Aspyr (Linux)")
    assert_equal "Aspyr", Catalog::SetNames.company("Aspyr (Mac/Linux)")
    assert_equal "Feral Interactive", Catalog::SetNames.company("Feral Interactive (Mac, Linux & Windows)")
    assert_equal "Aspyr", Catalog::SetNames.company("Aspyr (Mac and Linux)")
    assert_equal "Studio (Paris)", Catalog::SetNames.company("Studio (Paris)")
    assert_equal "PlayWay", Catalog::SetNames.company("PlayWay S.A.")
    assert_equal "Daedalic Entertainment", Catalog::SetNames.company("Daedalic Entertainment GmbH")
    assert_equal "Spike Chunsoft", Catalog::SetNames.company("Spike Chunsoft Co., Ltd")
    assert_equal "SEGA", Catalog::SetNames.company("SEGA Corporation")
    assert_equal "Studio", Catalog::SetNames.company("Studio S.R.L.")
    assert_equal "Square Enix", Catalog::SetNames.company("Square Enix K.K.")
    assert_equal "Ubisoft", Catalog::SetNames.company("Ubisoft™ Inc.")
    assert_equal "Team17 Digital", Catalog::SetNames.company("Team17 Digital Limited")
  end

  test "only trailing legal suffixes go: a word inside the name stays" do
    assert_equal "Co-op Studio", Catalog::SetNames.company("Co-op Studio")
    assert_equal "Disco Corp Games", Catalog::SetNames.company("Disco Corp Games LLC")
    assert_equal "Limited Run Games", Catalog::SetNames.company("Limited Run Games, Inc.")
  end

  test "a company's form ignores case" do
    assert_equal "capcom", Catalog::SetNames.company_form("CAPCOM Co., Ltd.")
    assert_equal Catalog::SetNames.company_form("Capcom"), Catalog::SetNames.company_form("CAPCOM Co., Ltd.")
  end

  test "a key is the form parameterized, or a digest of it when that leaves nothing" do
    assert_equal "final-fantasy", Catalog::SetNames.key("final fantasy")
    assert_equal "pokemon", Catalog::SetNames.key("pokémon")
    assert_match(/\Ax-\h{12}\z/, Catalog::SetNames.key("ファイナルファンタジー"))
    assert_equal Catalog::SetNames.key("ファイナルファンタジー"), Catalog::SetNames.key("ファイナルファンタジー")
    assert_not_equal Catalog::SetNames.key("ファイナルファンタジー"), Catalog::SetNames.key("ドラゴンクエスト")
  end

  test "a form partly without Latin transliteration takes the digest, so unrelated names never share a key" do
    first = Catalog::SetNames.key("ファイナルファンタジー 7")
    second = Catalog::SetNames.key("ドラゴンクエスト 7")

    assert_match(/\Ax-\h{12}\z/, first)
    assert_not_equal first, second
  end

  test "a title matches a name sharing a whole word of three letters or more that is no stopword" do
    assert Catalog::SetNames.title_matches?("Tom Clancy's Rainbow Six Siege", "Tom Clancy")
    assert Catalog::SetNames.title_matches?("Assassin's Creed Odyssey", "Assassin's Creed")
    assert_not Catalog::SetNames.title_matches?("Warhammer: Vermintide", "War")
    assert_not Catalog::SetNames.title_matches?("Clothing Store Simulator", "Estate Agent Simulator")
    assert_not Catalog::SetNames.title_matches?("Game of Thrones", "The Game")
    assert_not Catalog::SetNames.title_matches?("Mr. Shifty", "Mr. Robot")
  end

  test "a name's only word matches however short" do
    assert Catalog::SetNames.title_matches?("Ys VIII: Lacrimosa of DANA", "Ys")
    assert_not Catalog::SetNames.title_matches?("Yshtola's Tale", "Ys")
  end

  test "a name's words joined match a run of title words joined the same way" do
    assert Catalog::SetNames.title_matches?("Yu-Gi-Oh! Master Duel", "Yu-Gi-Oh!")
    assert Catalog::SetNames.title_matches?("Watch_Dogs 2", "WatchDogs")
    assert Catalog::SetNames.title_matches?("Watch Dogs: Legion", "WatchDogs")
    assert_not Catalog::SetNames.title_matches?("Watchmen Dogs", "WatchDogs")
  end

  test "no title matches nothing" do
    assert_not Catalog::SetNames.title_matches?(nil, "Hitman")
  end

  test "Science Adventure and World of Darkness are exempt from the title rule, whatever their case or suffix" do
    assert Catalog::SetNames.exempt_from_titles?("Science Adventure")
    assert Catalog::SetNames.exempt_from_titles?("world of darkness")
    assert_not Catalog::SetNames.exempt_from_titles?("Science")
  end
end
