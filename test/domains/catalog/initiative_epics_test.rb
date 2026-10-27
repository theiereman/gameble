require "test_helper"

# Catalog::InitiativeEpics: the epics of the initiative's ticket file, in
# order; a missing or broken file is a reading with a problem, never an
# exception.
class Catalog::InitiativeEpicsTest < ActiveSupport::TestCase
  def with_file(content)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tickets.toml")
      File.write(path, content)
      yield path
    end
  end

  test "the initiative's own file reads as a non-empty list of epics, each with a slug and a title" do
    reading = Catalog::InitiativeEpics.read(Rails.root.join("_bmad-output/initiative-gameble/tickets.toml"))

    assert_nil reading.problem
    assert_not_empty reading.epics
    assert reading.epics.all? { it.slug.start_with?("epic-") && it.title.present? }
    assert_equal reading.epics.map(&:slug).uniq, reading.epics.map(&:slug)
  end

  test "the epics come in the file's order, with their titles; other tables and keys are ignored" do
    with_file(<<~TOML) do |path|
      # The epics.
      [meta]
      name = "x"

      [[epic]]
      id = 2
      slug = "epic-b"
      title = "  Second   epic "
      covers = ["a", "b"]

      [[epic]]
      id = 1
      slug = "epic-a"
      title = "First epic"
    TOML
      reading = Catalog::InitiativeEpics.read(path)

      assert_equal [ [ "epic-b", "Second epic" ], [ "epic-a", "First epic" ] ], reading.epics.map { [ it.slug, it.title ] }
    end
  end

  test "an epic without a title is titled with its slug" do
    with_file("[[epic]]\nslug = \"epic-a\"\n") do |path|
      assert_equal [ Catalog::InitiativeEpics::Epic.new(slug: "epic-a", title: "epic-a") ], Catalog::InitiativeEpics.read(path).epics
    end
  end

  test "a missing file is a problem" do
    reading = Catalog::InitiativeEpics.read(Rails.root.join("tmp/no-such-dir/tickets.toml"))

    assert_nil reading.epics
    assert_match(/\Amissing: .*tickets\.toml\z/, reading.problem)
  end

  {
    "broken TOML" => "[[epic]\nslug = ",
    "a key defined twice" => "[[epic]]\nslug = \"a\"\nslug = \"b\"\n"
  }.each do |name, content|
    test "#{name} is an unparseable file" do
      with_file(content) do |path|
        reading = Catalog::InitiativeEpics.read(path)

        assert_nil reading.epics
        assert_match(/\Aunparseable: /, reading.problem)
      end
    end
  end

  {
    "no epic" => [ "[meta]\nname = \"x\"\n", "no epic in the file" ],
    "an epic without a slug" => [ "[[epic]]\ntitle = \"x\"\n", "an epic has no slug" ],
    "a blank slug" => [ "[[epic]]\nslug = \"\"\n", "an epic has no slug" ],
    "a slug that is no string" => [ "[[epic]]\nslug = 3\n", "an epic has no slug" ],
    "epic as a plain key" => [ "epic = \"x\"\n", "no epic in the file" ]
  }.each do |name, (content, problem)|
    test "#{name} is a problem" do
      with_file(content) do |path|
        reading = Catalog::InitiativeEpics.read(path)

        assert_nil reading.epics
        assert_equal problem, reading.problem
      end
    end
  end
end
