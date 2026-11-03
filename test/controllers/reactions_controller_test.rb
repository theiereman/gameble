require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/feed_reactions"
require_relative "../support/steam_sign_in"

# Reacting to a feed entry from the feed: the answers in Turbo Stream and
# HTML, the bar a lazy frame loads, and every refusal.
class ReactionsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include FeedReactions
  include SteamSignIn

  setup do
    @author = accounts_players(:player)
    @author.update!(persona_name: "Hugo")
    @reader = accounts_players(:moderator)
    @reader.update!(persona_name: "Sam")
    @entry = feed_entry_of(@author)
  end

  def reaction_path(entry = @entry, locale: :en) = feed_entry_reaction_path(locale:, token: entry.token)

  def reactions = Game::FeedReaction.where(feed_entry_id: @entry.id)

  def bar(token = @entry.token) = css_select("turbo-stream[action=replace][target=reactions-#{token}] template").first

  test "from Turbo, a reaction replaces the entry's bar and tells the player, in French and English" do
    sign_in(@reader)

    post reaction_path(locale: :fr), params: { kind: "heart" }, as: :turbo_stream

    assert_response :success
    assert_equal [ [ @reader.id, "heart" ] ], reactions.pluck(:player_id, :kind)
    assert_select "turbo-stream[action=replace][target=reactions-#{@entry.token}] template turbo-frame#reactions-#{@entry.token}"
    assert_select ".feed__reaction--mine[data-reaction-kind=heart][aria-pressed=true]", 1
    assert_select ".feed__reaction-choice[aria-pressed=true]", 1
    assert_select ".feed__reaction-choice[data-reaction-kind=heart][aria-pressed=true]"
    assert_select "[data-reaction-count='#{ReactionStream.slot(@entry.token, "heart")}']", count: 2, text: "1"
    assert_select "turbo-stream[action=update][target=reaction-status] template", "Réaction envoyée\u202f: Cœur."

    post reaction_path, params: { kind: "wow" }, as: :turbo_stream

    assert_select "turbo-stream[action=update][target=reaction-status] template", "Reaction sent: Wow."
  end

  test "the own reaction, held in place of the +, and its choice post its removal; the others post themselves" do
    sign_in(@reader)
    post reaction_path, params: { kind: "gg" }, as: :turbo_stream

    assert_select "form[action='#{reaction_path}'] input[name=_method][value=delete]", 2
    assert_select "form:has(.feed__reaction--mine[data-reaction-kind=gg]) input[name=_method][value=delete]"
    assert_select "form:has(.feed__reaction-choice[data-reaction-kind=gg]) input[name=_method][value=delete]"
    assert_select "button[data-reaction-toggle]", 0
    assert_select ".feed__reaction-pill--mine", 1
    assert_select ".feed__reaction-pill--mine[data-reaction-pill=gg]"
    assert_select ".feed__reaction-choice[data-reaction-kind=heart][aria-pressed=false]"
    assert_select "form:has(.feed__reaction-choice[data-reaction-kind=heart]) input[name=kind][value=heart]"
    assert_select "[data-reaction-pill=heart] form input[name=kind][value=heart]"
  end

  test "a reaction is changed, then removed" do
    sign_in(@reader)

    post reaction_path, params: { kind: "heart" }, as: :turbo_stream
    post reaction_path, params: { kind: "wow" }, as: :turbo_stream
    assert_equal [ "wow" ], reactions.pluck(:kind)

    delete reaction_path, as: :turbo_stream

    assert_response :success
    assert_empty reactions
    assert_select "button[aria-pressed=true]", 0
    assert_select "button[data-reaction-toggle][aria-expanded=false][aria-label='Add a reaction']", 1
    assert_select "turbo-stream[action=update][target=reaction-status] template", "Reaction removed."
  end

  test "without Turbo, the answer is a redirect back to the feed" do
    sign_in(@reader)

    post reaction_path, params: { kind: "heart" }, headers: { "Referer" => feed_url(locale: :en) }

    assert_redirected_to feed_url(locale: :en)
    assert_response :see_other
    assert_equal 1, reactions.count

    delete reaction_path

    assert_response :see_other
    assert_empty reactions
  end

  test "a visitor is sent to sign in and writes nothing" do
    post reaction_path, params: { kind: "heart" }

    assert_redirected_to home_path(locale: :en)
    assert_empty reactions
    delete reaction_path
    assert_response :see_other
  end

  test "an unknown kind is refused with a toast and writes nothing" do
    sign_in(@reader)

    post reaction_path, params: { kind: "angry" }, as: :turbo_stream

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=append][target=toasts] template .toast--alert .toast__message", "That reaction does not exist."
    assert_empty reactions
  end

  test "an entry that does not exist, or that the player may not see, is not found" do
    sign_in(@reader)

    post feed_entry_reaction_path(locale: :en, token: SecureRandom.uuid), params: { kind: "heart" }, as: :turbo_stream
    assert_response :not_found
    assert_select ".toast__message", "That feed entry could not be found."

    @author.update!(visibility: "private")
    post reaction_path, params: { kind: "heart" }, as: :turbo_stream
    assert_response :not_found
    assert_empty reactions
  end

  test "a malformed token reaches no action" do
    sign_in(@reader)

    post "/en/feed/entries/#{@entry.id}/reaction", params: { kind: "heart" }

    assert_response :not_found
  end

  test "the answer names only the public players who reacted, and carries no database id" do
    react(accounts_players(:administrator).tap { it.update!(persona_name: "Léa", visibility: :friends_only) }, @entry, "heart")
    sign_in(@reader)

    post reaction_path, params: { kind: "heart" }, as: :turbo_stream

    assert_select ".feed__reaction-who-names", "Sam and 1 other"
    assert_no_match(/Hugo|Léa/, response.body)
    assert_no_match(%r{entries/#{@entry.id}/}, response.body)
    assert_no_match(/player/i, response.body)
  end

  test "the bar a lazy frame loads is the viewer's: buttons and their mark for a player, counters alone for a visitor" do
    react(@reader, @entry, "thumb")
    react(@author, @entry, "wow")

    get feed_entry_reactions_path(locale: :en, token: @entry.token)
    assert_response :success
    assert_select "turbo-frame#reactions-#{@entry.token} .feed__reaction--static", 5
    assert_select "turbo-frame button", 0
    assert_select "[data-reaction-count='#{ReactionStream.slot(@entry.token, "thumb")}']", "1"
    assert_select "[data-reaction-count='#{ReactionStream.slot(@entry.token, "heart")}']", ""

    sign_in(@reader)
    get feed_entry_reactions_path(locale: :en, token: @entry.token)

    assert_select "turbo-frame#reactions-#{@entry.token} .feed__reaction-pill button", 5
    assert_select "turbo-frame#reactions-#{@entry.token} .feed__reaction-choice", 5
    assert_select ".feed__reaction--mine[data-reaction-kind=thumb][aria-pressed=true]", 1
    assert_select ".feed__reaction-choice[aria-pressed=true]", 1
  end

  test "each reaction shows its exported icon at 20 × 20, decorative beside its hidden name" do
    sign_in(@reader)
    get feed_entry_reactions_path(locale: :en, token: @entry.token)

    assert_select ".feed__reaction-pill button[data-reaction-kind=middle_finger] img.feed__reaction-icon[src*='middle-finger'][alt=''][width='20'][height='20']"
    assert_select ".feed__reaction-pill button[data-reaction-kind=middle_finger] .visually-hidden", "Middle finger"
    assert_select ".feed__reaction-choice[data-reaction-kind=middle_finger] img[src*='middle-finger'][alt=''][width='20'][height='20']"
    assert_select "img.feed__reaction-icon[width='20'][height='20']", 5
  end

  test "the bar of an entry the viewer may not see is not found" do
    @author.update!(visibility: "private")

    get feed_entry_reactions_path(locale: :en, token: @entry.token)

    assert_response :not_found
  end

  test "reading a bar writes nothing" do
    assert_no_difference -> { Game::FeedReaction.count } do
      get feed_entry_reactions_path(locale: :en, token: @entry.token)
    end
  end

  test "the sixty-first reaction in a minute is throttled" do
    sign_in(@reader)

    with_counting_rate_limit(ReactionsController) do
      60.times { post reaction_path, params: { kind: "heart" }, as: :turbo_stream }
      post reaction_path, params: { kind: "wow" }, as: :turbo_stream
    end

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_select ".toast__message", "Too many reactions in a minute. Try again in a moment."
    assert_equal [ "heart" ], reactions.pluck(:kind)
  end
end
