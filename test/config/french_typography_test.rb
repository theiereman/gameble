require "test_helper"

class FrenchTypographyTest < ActiveSupport::TestCase
  WIDE_SPACE_AT_A_MARK = /[ \u00A0][:;?!»]|«[ \u00A0]/

  test "French copy puts a narrow no-break space before : ; ? ! and inside guillemets" do
    offenses = french_locale_files.flat_map do |file|
      wide_spaces_at_marks(YAML.safe_load_file(file, aliases: true)).map { |path, fragment| "#{file.relative_path_from(Rails.root)} #{path}: #{fragment.inspect}" }
    end

    assert_empty offenses, "Use U+202F before : ; ? ! and inside « »:\n#{offenses.join("\n")}"
  end

  test "the check flags a plain or no-break space at a mark and leaves the narrow one and bare colons alone" do
    flagged = { "a" => "Prix : 1", "b" => "« x »", "c" => "Oui ?", "d" => "Total\u00A0:", "e" => [ "Non !" ] }
    clean = { "a" => "Prix\u202F: 1", "b" => "«\u202Fx\u202F»", "c" => "steam:fill", "d" => "https://x", "e" => "Oui\u202F?" }

    assert_equal [ "a", "b", "c", "d", "e.0" ], wide_spaces_at_marks(flagged).map(&:first).uniq
    assert_equal [ [ "b", "« x" ], [ "b", "« x »" ] ], wide_spaces_at_marks(flagged).select { |path, _| path == "b" }
    assert_empty wide_spaces_at_marks(clean)
  end

  private
    def french_locale_files
      Rails.root.glob("config/locales/**/fr.yml")
    end

    def wide_spaces_at_marks(node, path = [])
      case node
      when Hash then node.flat_map { |key, value| wide_spaces_at_marks(value, path + [ key ]) }
      when Array then node.each_with_index.flat_map { |value, index| wide_spaces_at_marks(value, path + [ index ]) }
      when String then fragments_at_marks(node).map { |fragment| [ path.join("."), fragment ] }
      else []
      end
    end

    def fragments_at_marks(text)
      offsets = []
      text.scan(WIDE_SPACE_AT_A_MARK) { offsets << Regexp.last_match.begin(0) }
      offsets.map { |offset| text[[ offset - 12, 0 ].max..(offset + 2)] }
    end
end
