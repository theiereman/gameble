require "test_helper"
require "open3"

class LegalSettingsTest < ActiveSupport::TestCase
  VARIABLES = %w[LEGAL_CONTACT_EMAIL LEGAL_HOST_NAME LEGAL_HOST_ADDRESS].freeze

  # A production boot in a subprocess: its status and output.
  def boot_production(omitted: nil, dummy: nil)
    env = VARIABLES.index_with { |name| name == omitted ? nil : "value" }
    env.update("RAILS_ENV" => "production", "SECRET_KEY_BASE" => "0" * 128, "PUBLIC_URL" => "https://gameble.example", "SECRET_KEY_BASE_DUMMY" => dummy)
    Open3.capture2e(env, "bin/rails", "runner", "puts :booted", chdir: Rails.root.to_s)
  end

  test "production refuses to boot when a legal variable is missing, naming it" do
    VARIABLES.each do |name|
      output, status = boot_production(omitted: name)

      assert_not status.success?, "booted without #{name}"
      assert_match(/Missing #{name}\b/, output)
    end
  end

  test "production boots with every legal variable, and in the Docker build without them" do
    output, status = boot_production
    assert status.success?, output

    output, status = boot_production(omitted: "LEGAL_HOST_NAME", dummy: "1")
    assert status.success?, output
  end

  Dir[Rails.root.join("config/deploy.*.yml")].each do |path|
    destination = File.basename(path, ".yml").delete_prefix("deploy.")

    test "the #{destination} destination sets every legal variable" do
      clear = YAML.safe_load(File.read(path), aliases: true).dig("env", "clear")

      VARIABLES.each { |name| assert_predicate clear[name], :present?, "config/deploy.#{destination}.yml must set env.clear.#{name}" }
    end
  end
end
