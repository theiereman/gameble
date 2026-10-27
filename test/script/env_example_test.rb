require "test_helper"

class EnvExampleTest < ActiveSupport::TestCase
  SOURCES = %w[app config lib script].freeze
  READ = /ENV(?:\.[a-z_?]+)?[\[(]\s*["']([A-Z][A-Z0-9_]*)["']|"(LEGAL_[A-Z_]+)"/

  test "every variable the code reads is listed in .env.example" do
    read = SOURCES.flat_map { |dir| Dir[Rails.root.join(dir, "**/*.{rb,yml,erb,ru}")] }
      .flat_map { |path| File.read(path).scan(READ).flatten.compact }.uniq
    listed = File.read(Rails.root.join(".env.example")).scan(/^#?\s*([A-Z][A-Z0-9_]*)=/).flatten

    assert_empty read - listed
  end
end
