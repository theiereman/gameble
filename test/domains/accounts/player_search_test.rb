require "test_helper"

class Accounts::PlayerSearchTest < ActiveSupport::TestCase
  setup do
    Accounts::Player.update_all(created_at: 1.week.ago)
  end

  def player(steam_id, name = nil, at: 1.hour.ago, **attributes)
    Accounts::Player.create!(steam_id:, persona_name: name, created_at: at, **attributes).tap do |player|
      Accounts::Identity.create!(player:, provider: "steam", uid: steam_id) if steam_id
    end
  end

  def search(query) = Accounts::PlayerSearch.call(query).to_a

  test "every player whose account remains, banned ones included, the newest account first" do
    older = player("76561197960370001", "Older", at: 2.hours.ago)
    newer = player("76561197960370002", "Newer", at: 1.hour.ago)
    banned = player("76561197960370003", "Exile", at: 30.minutes.ago, banned_at: 10.minutes.ago)
    deleted = player("76561197960370004", "Ghost", at: 1.minute.ago)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    players = Accounts::PlayerSearch.call.to_a

    assert_equal [ banned, newer, older ], players.first(3)
    assert_not_includes players, deleted
    assert_equal Accounts::Player.where(deleted_at: nil).count, players.size
    assert_equal players, search("   ")
  end

  test "a part of a name, in any case, around spaces" do
    gabe = player("76561197960370011", "Gabe the Rude")
    player("76561197960370012", "Someone else")

    assert_equal [ gabe ], search("  tHE rU  ")
  end

  test "a full Steam id finds its player exactly, and any name holding those digits" do
    target = player("76561197960370021", "Target")
    namesake = player("76561197960370022", "fan of 76561197960370021", at: 2.hours.ago)

    assert_equal [ target, namesake ], search("76561197960370021")
  end

  test "a player without a Steam id is found by name, and a Steam id found through the identity row only" do
    handle = player(nil, "Brother-4F7K2Q")
    google = Accounts::Identity.create!(player: handle, provider: "google", uid: "76561197960370099")

    assert_equal [ handle ], search("brother-4f7")
    assert_empty search(google.uid)
  end

  test "a part of a Steam id finds no one unless a name holds it" do
    player("76561197960370031", "Target")

    assert_empty search("7656119796037003")
    assert_empty search("370031")
  end

  test "the wildcards of LIKE match themselves" do
    percent = player("76561197960370041", "100% sure")
    underscore = player("76561197960370042", "snake_case")
    player("76561197960370043", "Plain")

    assert_equal [ percent ], search("%")
    assert_equal [ underscore ], search("_")
  end

  test "a deleted account is found neither by its old name nor by its old Steam id" do
    deleted = player("76561197960370051", "Ghost")
    Accounts::DeletePlayer.new.call(player: deleted).value!

    assert_empty search("Ghost")
    assert_empty search("76561197960370051")
  end

  test "a banned player is found" do
    banned = player("76561197960370061", "Exile", banned_at: 1.hour.ago)

    assert_equal [ banned ], search("exile")
  end

  test "an overlong query is searched on its first characters" do
    name = "a" * Accounts::PlayerSearch::MAX_QUERY
    long = player("76561197960370071", name)

    assert_equal [ long ], search("#{name}tail beyond the cap")
    assert_equal name, Accounts::PlayerSearch.normalize(" #{name}tail ")
  end

  test "a query is cleaned as a stored name is: a NUL byte dropped, a no-break or double space made one plain space" do
    gabe = player("76561197960370081", "Gabe the Rude")

    assert_equal [ gabe ], search("Gabe\u0000 the")
    assert_equal [ gabe ], search("Gabe the")
    assert_equal [ gabe ], search("Gabe  the")
    assert_equal Accounts::PlayerSearch.call.to_a, search("\u0000")
  end

  test "a query that is not a string searches nothing out" do
    assert_equal "", Accounts::PlayerSearch.normalize([ "Gabe" ])
    assert_equal "", Accounts::PlayerSearch.normalize(nil)
  end
end
