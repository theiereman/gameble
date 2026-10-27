require "test_helper"
require "open3"
require "tmpdir"

# The two repository checks run against a temporary directory with one planted offender each.
class MechanicalChecksTest < ActiveSupport::TestCase
  PLANNING_REFERENCES = Rails.root.join("script/check_planning_references")
  FILE_SIZES = Rails.root.join("script/check_file_sizes")

  setup { @dir = Dir.mktmpdir }
  teardown { FileUtils.remove_entry(@dir) }

  test "planning references are reported with their file and line" do
    write("app/model.rb", "class Model\n  # see #{"AD"}-7\nend\n")

    output, status = run_check(PLANNING_REFERENCES)

    assert_not status.success?
    assert_includes output, "app/model.rb:2:"
  end

  test "every kind of planning reference is caught" do
    [ %w[CAP -3], %w[R -12], [ "story", " 4.1" ], [ "epic", " 9" ], %w[DESIGN .md], %w[EXPERIENCE .md] ].map(&:join).each_with_index do |reference, index|
      write("lib/file_#{index}.rb", "# #{reference}\n")
    end

    output, = run_check(PLANNING_REFERENCES)

    assert_equal 6, output.lines.grep(%r{lib/file_}).size
  end

  test "clean files pass the planning references check" do
    write("app/clean.rb", "class Clean; end\n# the epic of a hero, a story about nothing\n")

    _, status = run_check(PLANNING_REFERENCES)

    assert status.success?
  end

  test "a TypeScript file over 400 lines is reported" do
    write("app/big.ts", "const a = 1\n" * 401)
    write("app/fine.ts", "const a = 1\n" * 400)

    output, status = run_check(FILE_SIZES)

    assert_not status.success?
    assert_includes output, "app/big.ts: 401 lines"
    assert_not_includes output, "fine.ts"
  end

  test "a stylesheet is limited to 500 lines" do
    write("app/big.css", ".a {}\n" * 501)
    write("app/fine.css", ".a {}\n" * 500)

    output, = run_check(FILE_SIZES)

    assert_includes output, "app/big.css"
    assert_not_includes output, "fine.css"
  end

  test "tests and generated schemas are exempt from the size limit" do
    write("test/big_test.rb", "x = 1\n" * 500)
    write("app/big.test.ts", "const a = 1\n" * 500)
    write("db/schema.rb", "x = 1\n" * 500)
    write("db/queue_schema.rb", "x = 1\n" * 500)
    write("script/tool.mjs", "const a = 1\n" * 500)

    _, status = run_check(FILE_SIZES)

    assert status.success?
  end

  private

  def write(path, content)
    full = File.join(@dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def run_check(script)
    Open3.capture2e(script.to_s, ".", chdir: @dir)
  end
end
