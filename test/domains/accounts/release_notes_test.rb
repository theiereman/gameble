require "test_helper"

class Accounts::ReleaseNotesTest < ActiveSupport::TestCase
  setup do
    @administrator = accounts_players(:administrator)
    @player = accounts_players(:player)
  end

  def event_store = Rails.configuration.event_store

  def version(name) = Accounts::ReleaseVersion.parse(name)

  def create(version: "v1.3.0", state: "draft", **texts)
    Accounts::CreateReleaseNote.new.call(staff: @administrator, version:, state:, **texts)
  end

  def complete(**overrides)
    { title_fr: "Titre", title_en: "Title", body_fr: "- Une ligne", body_en: "- One line" }.merge(overrides)
  end

  def ready(name) = create(version: name, state: "ready", **complete).value!

  test "a version is a production release, ordered by its numbers; a candidate, a sha or dev is none" do
    assert_operator version("v1.10.0"), :>, version("v1.9.2")
    assert_equal "v1.3.0", version(" v1.3.0 ").to_s
    [ "v1.3.0-rc.2", "1.3.0", "0123abc", "dev", nil ].each { assert_nil version(it) }
  end

  test "a note is created as a draft for one release, its texts cleaned, publishing its creation" do
    note = create(title_fr: "  Les   capsules ", body_en: "- One\r\n\n\n\n- Two  ").value!

    assert_predicate note, :draft?
    assert_equal [ "Les capsules", "- One\n\n- Two" ], [ note.title_fr, note.body_en ]
    assert_equal 24, note.token.length
    event = event_store.read.stream(Accounts::ReleaseNote.stream_name).last
    assert_kind_of Accounts::ReleaseNoteCreated, event
    assert_equal({ release_note_id: note.id, staff_id: @administrator.id, state: "draft" }, event.data)
  end

  test "a version is written vMAJOR.MINOR.PATCH and has one note; texts keep to their lengths" do
    assert_equal :invalid_release_version, create(version: "v1.3.0-rc.1").failure
    create.value!
    assert_equal :release_version_taken, create.failure
    assert_equal :invalid_release_note, create(version: "v1.4.0", title_en: "x" * 81).failure
    assert_equal :invalid_release_note, create(version: "v1.4.0", body_fr: "x" * 1501).failure
    assert create(version: "v1.4.0", title_en: "x" * 80, body_fr: "x" * 1500).success?
  end

  test "a note is ready only with its title and text in both languages, created ready or marked so" do
    assert_equal :incomplete_release_note, create(state: "ready", **complete(body_en: " ")).failure
    note = create(**complete(title_fr: "")).value!
    change = ->(state) { Accounts::ChangeReleaseNoteState.new.call(staff: @administrator, release_note: note, state:) }

    assert_equal :incomplete_release_note, change.("ready").failure
    Accounts::EditReleaseNote.new.call(staff: @administrator, release_note: note, **complete).value!
    assert_predicate change.("ready").value!, :ready?
    assert_equal :incomplete_release_note,
      Accounts::EditReleaseNote.new.call(staff: @administrator, release_note: note, **complete(title_en: "")).failure
    assert_equal :invalid_release_note_state, change.("shown").failure
    assert_predicate change.("skipped").value!, :skipped?
  end

  test "production shows the newest ready note at or below the release it runs, never on a candidate" do
    ready("v1.2.0")
    ready("v1.3.0")
    create(version: "v1.4.0", **complete)
    live = ->(running) { Accounts::ReleaseNotes.live(running: version(running))&.version }

    assert_nil live.("v1.1.9")
    assert_equal "v1.2.0", live.("v1.2.5")
    assert_equal "v1.3.0", live.("v1.3.0")
    assert_equal "v1.3.0", live.("v1.4.0")
    assert_nil live.("v1.3.0-rc.2")
  end

  test "a player sees the live note once; a new account sees it too" do
    note = ready("v1.3.0")
    running = version("v1.3.0")
    assert_equal note, Accounts::ReleaseNotes.unseen_by(@player, running:)

    assert Accounts::SeeReleaseNote.new.call(player_id: @player.id, release_note_id: note.id).value!
    assert_not Accounts::SeeReleaseNote.new.call(player_id: @player.id, release_note_id: note.id).value!

    assert_nil Accounts::ReleaseNotes.unseen_by(@player, running:)
    assert_equal note, Accounts::ReleaseNotes.unseen_by(accounts_players(:moderator), running:)
    assert_equal [ @player.id ], note.reads.pluck(:player_id)
    event = event_store.read.stream("Accounts::Player$#{@player.id}").last
    assert_equal({ release_note_id: note.id, player_id: @player.id }, event.data)
  end

  test "a deleted player's sight is not recorded and is erased with the account" do
    note = ready("v1.3.0")
    Accounts::SeeReleaseNote.new.call(player_id: @player.id, release_note_id: note.id).value!

    Accounts::DeletePlayer.new.call(player: @player).value!

    assert_empty note.reads
    assert_not Accounts::SeeReleaseNote.new.call(player_id: @player.id, release_note_id: note.id).value!
  end

  test "the running release lacks a note until one for it is ready or skipped" do
    running = version("v1.3.0")
    assert_equal running, Accounts::ReleaseNotes.missing(running:)
    assert_nil Accounts::ReleaseNotes.missing(running: nil)

    note = create(**complete).value!
    assert_equal running, Accounts::ReleaseNotes.missing(running:)
    Accounts::ChangeReleaseNoteState.new.call(staff: @administrator, release_note: note, state: "skipped").value!
    assert_nil Accounts::ReleaseNotes.missing(running:)
    assert_equal version("v1.3.1"), Accounts::ReleaseNotes.missing(running: version("v1.3.1"))
  end

  test "a body reads as paragraphs and sections of items" do
    blocks = Accounts::ReleaseNoteText.blocks("Faster capsules.\n\n## New\n- One\n-  Two \n## Fixes\n- Three\n- Four\nThanks!\n- Loose")

    paragraph, new, fixes, thanks, loose = blocks
    assert_equal "Faster capsules.", paragraph.text
    assert_equal [ "New", %w[One Two] ], [ new.title, new.items ]
    assert_equal [ "Fixes", %w[Three Four] ], [ fixes.title, fixes.items ]
    assert_equal "Thanks!", thanks.text
    assert_equal [ nil, %w[Loose] ], [ loose.title, loose.items ]
  end

  test "a release's commits draft its features and fixes, crediting their contributors and leaving maintenance out" do
    changes = Accounts::ReleaseChanges.new(since: "v1.2.1", head: "v1.3.0-rc.2", commits: [
      { subject: "feat(booster): a capsule opens at once", credits: [] },
      { subject: "fix: cards are dealt face up", credits: %w[micilico thoKling micilico] },
      { subject: "docs(tickets): file the epic", credits: %w[micilico] },
      { subject: "Merge develop" }, { subject: "feat!: breaking" }
    ])

    assert_equal [ "A capsule opens at once", "Breaking" ], changes.features.map(&:subject)
    assert_equal "## Nouveautés\n- A capsule opens at once\n- Breaking\n\n## Corrections\n- Cards are dealt face up (merci @micilico, @thoKling)",
      changes.draft_body(:fr)
    assert_equal "## New\n- A capsule opens at once\n- Breaking\n\n## Fixes\n- Cards are dealt face up (thanks @micilico, @thoKling)",
      changes.draft_body(:en)
    assert_predicate Accounts::ReleaseChanges.new(since: "v1", head: "v2", commits: [ { subject: "chore: x" } ]), :empty?
  end
end
