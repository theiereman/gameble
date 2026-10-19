require "test_helper"
require "open3"
require "tmpdir"
require "yaml"

# The landing's roadmap: config/roadmap.yml and config/locales/roadmap/ are
# exactly what script/roadmap/export.py writes from the initiative's ticket
# tree, so a milestone's wording or status changes there, never by hand.
class RoadmapExportTest < ActiveSupport::TestCase
  LANDING = { en: "Visitors meet gameble", fr: "Bienvenue à bord" }.freeze

  test "the committed roadmap matches the initiative" do
    output, status = export("--check")

    assert_predicate status, :success?, output
    assert_match(/up to date/, output)
  end

  test "the app reads the committed roadmap" do
    assert_kind_of Array, Rails.application.config_for(:roadmap).fetch(:milestones)
    %i[en fr].each do |locale|
      assert I18n.exists?("roadmap.milestones", locale), "roadmap.milestones is missing in #{locale}"
      assert_kind_of Hash, I18n.t("roadmap.milestones", locale:)
    end
  end

  test "the chosen epics and stories become milestones in build order with their statuses" do
    Dir.mktmpdir do |dir|
      output, status = export_tree(dir, curated_tree)

      assert_predicate status, :success?, output
      assert_match(/roadmap: 5 milestones, 6 stories written/, output)
      assert_equal [
        { "key" => "visitor_landing", "status" => "in_progress", "stories" => [
          { "key" => "the_roadmap_derives_from_the_initiative", "status" => "done" },
          { "key" => "the_lamp_finds_the_lost_games", "status" => "in_progress" },
          { "key" => "fonts_for_everyone", "status" => "in_progress" },
          { "key" => "the_pioneer_row", "status" => "to_come" }
        ] },
        { "key" => "first_light", "status" => "done", "stories" => [
          { "key" => "sign_in_with_steam", "status" => "done" }
        ] },
        { "key" => "far_future", "status" => "in_progress", "stories" => [] },
        { "key" => "wrapped_up", "status" => "done", "stories" => [] },
        { "key" => "next_season", "status" => "to_come", "stories" => [
          { "key" => "seasons_carry_over", "status" => "to_come" }
        ] }
      ], roadmap(dir)
    end
  end

  test "each locale file holds the milestones' and stories' wording in its language" do
    Dir.mktmpdir do |dir|
      export_tree(dir, curated_tree)

      fr = YAML.load_file(File.join(dir, "out/config/locales/roadmap/fr.yml")).dig("fr", "roadmap", "milestones")
      en = YAML.load_file(File.join(dir, "out/config/locales/roadmap/en.yml")).dig("en", "roadmap", "milestones")

      assert_equal %w[visitor_landing first_light far_future wrapped_up next_season], fr.keys
      assert_equal "Bienvenue à bord", fr.dig("visitor_landing", "name")
      assert_equal "La feuille de route", fr.dig("visitor_landing", "stories", "the_roadmap_derives_from_the_initiative")
      assert_equal "The roadmap", en.dig("visitor_landing", "stories", "the_roadmap_derives_from_the_initiative")
      assert_equal({}, en.dig("far_future", "stories"))
      assert_equal fr.transform_values { |milestone| milestone["stories"].keys }, en.transform_values { |milestone| milestone["stories"].keys }
    end
  end

  test "a tree with no roadmap field gives an empty roadmap" do
    Dir.mktmpdir do |dir|
      output, status = export_tree(dir, [ epic("epic-unchosen", entries: [ entry("Some work", status: "done") ]) ])

      assert_predicate status, :success?, output
      assert_equal [], roadmap(dir)
      assert_equal({}, YAML.load_file(File.join(dir, "out/config/locales/roadmap/en.yml")).dig("en", "roadmap", "milestones"))
      assert_equal({}, YAML.load_file(File.join(dir, "out/config/locales/roadmap/fr.yml")).dig("fr", "roadmap", "milestones"))
    end
  end

  test "a second export changes no file, not even its modification time" do
    Dir.mktmpdir do |dir|
      export_tree(dir, curated_tree)
      before = snapshot(File.join(dir, "out"))

      output, status = export(*tree_args(dir))

      assert_predicate status, :success?, output
      assert_match(/up to date/, output)
      assert_equal before, snapshot(File.join(dir, "out"))
    end
  end

  test "the check passes right after an export" do
    Dir.mktmpdir do |dir|
      export_tree(dir, curated_tree)

      output, status = export("--check", *tree_args(dir))

      assert_predicate status, :success?, output
      assert_match(/roadmap: 5 milestones, 6 stories up to date/, output)
    end
  end

  test "the check fails and names the roadmap when a shown ticket's status changes" do
    Dir.mktmpdir do |dir|
      export_tree(dir, curated_tree)
      plan = File.join(dir, "initiative-demo/epic-visitor-landing/story-2-plan.md")
      File.write(plan, File.read(plan).sub("status: in-progress", "status: done"))

      output, status = export("--check", *tree_args(dir))

      assert_not_predicate status, :success?
      assert_match(%r{differs: .*config/roadmap\.yml}, output)
      assert_no_match(/differs: .*locales/, output)
      assert_match(%r{run: python3 script/roadmap/export\.py}, output)
    end
  end

  test "the check fails and names the locale file whose wording changed" do
    Dir.mktmpdir do |dir|
      export_tree(dir, curated_tree)
      breakdown = File.join(dir, "initiative-demo/tickets.toml")
      File.write(breakdown, File.read(breakdown).sub("Bienvenue à bord", "Montez à bord"))

      output, status = export("--check", *tree_args(dir))

      assert_not_predicate status, :success?
      assert_match(%r{differs: .*config/locales/roadmap/fr\.yml}, output)
      assert_no_match(%r{differs: .*roadmap/en\.yml}, output)
      assert_no_match(%r{differs: .*config/roadmap\.yml}, output)
    end
  end

  test "a roadmap field without both wordings fails naming its epic" do
    Dir.mktmpdir do |dir|
      output, status = export_tree(dir, [ epic("epic-visitor-landing", roadmap: { en: "Visitors meet gameble", fr: "" }) ])

      assert_not_predicate status, :success?
      assert_match(/epic-visitor-landing: `roadmap` must be/, output)
    end
  end

  test "a roadmap field that is not a table fails naming its entry" do
    Dir.mktmpdir do |dir|
      tree = [ epic("epic-visitor-landing", roadmap: LANDING, entries: [ entry("The pioneer row", roadmap: '"The pioneer row"') ]) ]

      output, status = export_tree(dir, tree)

      assert_not_predicate status, :success?
      assert_match(/"The pioneer row": `roadmap` must be/, output)
    end
  end

  test "a roadmap field under a dropped epic is still checked" do
    Dir.mktmpdir do |dir|
      tree = [ epic("epic-abandoned", roadmap: LANDING, status: "dropped", entries: [ entry("Never shipped", roadmap: '{ en = "Never" }') ]) ]

      output, status = export_tree(dir, tree)

      assert_not_predicate status, :success?
      assert_match(/"Never shipped": `roadmap` must be/, output)
    end
  end

  test "wording with control or invisible characters still loads" do
    Dir.mktmpdir do |dir|
      words = { en: "﻿Visitors\u0085meet gameble", fr: "Bienvenue\u0007à bord" }

      output, status = export_tree(dir, [ epic("epic-visitor-landing", roadmap: words) ])

      assert_predicate status, :success?, output
      assert_equal words[:en], YAML.load_file(File.join(dir, "out/config/locales/roadmap/en.yml")).dig("en", "roadmap", "milestones", "visitor_landing", "name")
      assert_equal words[:fr], YAML.load_file(File.join(dir, "out/config/locales/roadmap/fr.yml")).dig("fr", "roadmap", "milestones", "visitor_landing", "name")
    end
  end

  test "a chosen story whose epic is not chosen fails naming both" do
    Dir.mktmpdir do |dir|
      tree = [ epic("epic-visitor-landing", entries: [ entry("The pioneer row", roadmap: { en: "The pioneer", fr: "Le pionnier" }) ]) ]

      output, status = export_tree(dir, tree)

      assert_not_predicate status, :success?
      assert_match(/"The pioneer row" has a `roadmap` field but its epic epic-visitor-landing has none/, output)
    end
  end

  test "two chosen stories of one epic giving the same key fail" do
    Dir.mktmpdir do |dir|
      words = { en: "The pioneer", fr: "Le pionnier" }
      tree = [ epic("epic-visitor-landing", roadmap: LANDING, entries: [ entry("The pioneer row", roadmap: words), entry("The pioneer row!", roadmap: words) ]) ]

      output, status = export_tree(dir, tree)

      assert_not_predicate status, :success?
      assert_match(/both give the key the_pioneer_row/, output)
    end
  end

  test "a tree tickets.py refuses fails with its error" do
    Dir.mktmpdir do |dir|
      tree = [ epic("epic-visitor-landing", roadmap: LANDING, entries: [ entry("The pioneer row", type: "chore") ]) ]

      output, status = export_tree(dir, tree)

      assert_not_predicate status, :success?
      assert_match(/tickets\.py status failed: .*chore/, output)
    end
  end

  private

  def curated_tree
    [
      epic("epic-visitor-landing", roadmap: LANDING, entries: [
        entry("The roadmap derives from the initiative", roadmap: { en: "The roadmap", fr: "La feuille de route" }, status: "done"),
        entry("The lamp finds the lost games", roadmap: { en: "The lamp", fr: "La lampe" }, status: "in-progress"),
        entry("A dropped idea", roadmap: { en: "Dropped", fr: "Abandonnée" }, status: "dropped"),
        entry("Fonts for everyone", roadmap: { en: "Fonts", fr: "Polices" }, status: "in-review"),
        entry("The pioneer row", roadmap: { en: "The pioneer", fr: "Le pionnier" })
      ]),
      epic("epic-first-light", roadmap: { en: "First light", fr: "Première lumière" }, entries: [
        entry("Sign in with Steam", roadmap: { en: "Sign in", fr: "Connexion" }, status: "done"),
        entry("A cut corner", status: "dropped"),
        entry("Health check", status: "done")
      ]),
      epic("epic-far-future", roadmap: { en: "Far future", fr: "Futur lointain" }, status: "in-progress", entries: [ entry("Someday") ]),
      epic("epic-wrapped-up", roadmap: { en: "Wrapped up", fr: "Bouclée" }, status: "done", entries: [ entry("Loose end") ]),
      epic("epic-next-season", roadmap: { en: "Next season", fr: "Saison suivante" }, entries: [
        entry("Seasons carry over", roadmap: { en: "Carry over", fr: "Report" }, status: "draft")
      ]),
      epic("epic-abandoned", roadmap: { en: "Abandoned", fr: "Abandonnée" }, status: "dropped", entries: [
        entry("Never shipped", roadmap: { en: "Never", fr: "Jamais" }, status: "dropped")
      ]),
      epic("epic-unchosen", entries: [ entry("Back office", status: "done") ])
    ]
  end

  def epic(slug, roadmap: nil, status: nil, entries: [])
    { slug:, roadmap:, status:, entries: }
  end

  def entry(title, roadmap: nil, status: nil, type: "story")
    { title:, roadmap:, status:, type: }
  end

  def export_tree(dir, epics)
    write_tree(File.join(dir, "initiative-demo"), epics)
    export(*tree_args(dir))
  end

  def tree_args(dir)
    [ "--initiative", File.join(dir, "initiative-demo"), "--out", File.join(dir, "out") ]
  end

  def write_tree(root, epics)
    FileUtils.mkdir_p(root)
    File.write(File.join(root, "tickets.toml"), epics.each_with_index.map { |e, index| epic_table(e, index + 1) }.join("\n"))
    epics.each do |e|
      folder = File.join(root, e[:slug])
      FileUtils.mkdir_p(folder)
      File.write(File.join(folder, "#{e[:slug]}.md"), "---\ntype: epic\ntitle: #{e[:slug]}\n#{"status: #{e[:status]}\n" if e[:status]}---\n")
      File.write(File.join(folder, "tickets.toml"), e[:entries].each_with_index.map { |story, index| entry_table(story, index + 1) }.join("\n"))
      e[:entries].each_with_index do |story, index|
        next unless story[:status]

        File.write(File.join(folder, "story-#{index + 1}-plan.md"), "---\nticket: #{index + 1}\nstatus: #{story[:status]}\n---\n")
      end
    end
  end

  def epic_table(epic, id)
    "[[epic]]\nid = #{id}\nslug = #{epic[:slug].to_json}\ntitle = #{epic[:slug].to_json}\n#{roadmap_line(epic[:roadmap])}"
  end

  def entry_table(story, id)
    "[[entry]]\nid = #{id}\ntype = #{story[:type].to_json}\ntitle = #{story[:title].to_json}\n#{roadmap_line(story[:roadmap])}"
  end

  def roadmap_line(roadmap)
    case roadmap
    when Hash then "roadmap = { en = #{roadmap[:en].to_json}, fr = #{roadmap[:fr].to_json} }\n"
    when String then "roadmap = #{roadmap}\n"
    else ""
    end
  end

  def roadmap(dir)
    YAML.load_file(File.join(dir, "out/config/roadmap.yml")).dig("shared", "milestones")
  end

  def export(*args)
    Open3.capture2e("python3", "script/roadmap/export.py", *args, chdir: Rails.root.to_s)
  end

  def snapshot(dir)
    Dir.glob("**/*", base: dir).sort.select { |file| File.file?(File.join(dir, file)) }.to_h do |file|
      path = File.join(dir, file)
      [ file, [ File.binread(path), File.mtime(path).to_r ] ]
    end
  end
end
