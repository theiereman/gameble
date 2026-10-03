require "test_helper"
require "open3"

# The public base of shared links (CAP-9; epic 4 retrospective U1–U3):
# PUBLIC_URL parsed and checked at boot by config/initializers/public_url.rb,
# a malformed value refused everywhere, a missing one in production; and
# config/deploy.yml setting it.
class PublicUrlTest < ActiveSupport::TestCase
  SECRET = "s3cr3t-password".freeze

  {
    "https://gameble.example" => "https://gameble.example",
    "https://Gameble.example/" => "https://gameble.example",
    "HTTPS://GAMEBLE.EXAMPLE:443" => "https://gameble.example",
    "http://h:8080" => "http://h:8080",
    "http://192.168.1.6" => "http://192.168.1.6",
    "http://h:80/" => "http://h",
    "http://[::1]:3000" => "http://[::1]:3000",
    "https://h:65535" => "https://h:65535",
    "https://my-host.example" => "https://my-host.example",
    "https://h:8443" => "https://h:8443",
    " https://gameble.example " => "https://gameble.example"
  }.each do |value, base|
    test "#{value.inspect} is the base #{base.inspect}" do
      assert_equal base, PublicUrl.parse(value)
    end
  end

  [ nil, "", "   " ].each do |value|
    test "#{value.inspect} is no base" do
      assert_nil PublicUrl.parse(value)
    end
  end

  [ "gameble.example", "ftp://h", "https://h/app", "https://h/app/", "https://h?x", "https://h?", "https://h#top", "https://u:p@h",
    "https://#{SECRET}@h", "https://", "https:gameble.example", "//gameble.example", "https://exa mple.com", "javascript:alert(1)",
    "https://h:99999", "https://h:0", "https://h:65536", "https://a,b", "https://a_b.example", "https://a..b", "https://[zz::1]" ].each do |value|
    test "#{value.inspect} is refused, without echoing it" do
      error = assert_raises(PublicUrl::Invalid) { PublicUrl.parse(value) }

      # One message for every value: it names PUBLIC_URL, never the value.
      assert_match(/\APUBLIC_URL must be /, error.message)
      assert_not_includes error.message, "gameble.example"
      assert_not_includes error.message, SECRET
    end
  end

  test "configure: a missing value is refused in production, but for the Docker build's dummy secret" do
    production = ActiveSupport::EnvironmentInquirer.new("production")

    error = assert_raises(PublicUrl::Invalid) { PublicUrl.configure(nil, env: production, dummy_build: nil) }
    assert_includes error.message, "PUBLIC_URL"
    assert_raises(PublicUrl::Invalid) { PublicUrl.configure(" ", env: production, dummy_build: "") }
    assert_nil PublicUrl.configure(nil, env: production, dummy_build: "1")
    assert_equal "https://gameble.example", PublicUrl.configure("https://gameble.example/", env: production, dummy_build: nil)
  end

  test "configure: a missing value is no base outside production, a malformed one is refused there too" do
    %w[development test].each do |name|
      env = ActiveSupport::EnvironmentInquirer.new(name)

      assert_nil PublicUrl.configure(nil, env:, dummy_build: nil)
      assert_raises(PublicUrl::Invalid) { PublicUrl.configure("gameble.example", env:, dummy_build: nil) }
    end
  end

  # A production boot in a subprocess, every variable it reads given
  # explicitly (nil unsets it): its status and output.
  def boot_production(public_url:, dummy: nil)
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE" => "0" * 128, "PUBLIC_URL" => public_url, "SECRET_KEY_BASE_DUMMY" => dummy }
    script = %(puts "PUBLIC_URL_BASE=\#{Rails.configuration.x.public_url.inspect}")
    output, status = Open3.capture2e(env, "bin/rails", "runner", script, chdir: Rails.root.to_s)
    [ status, output ]
  end

  # The base a booted subprocess printed, or nil without the marker line.
  def printed_base(output) = output[/^PUBLIC_URL_BASE=(.*)$/, 1]

  test "production refuses to boot without PUBLIC_URL, or with a malformed one, naming PUBLIC_URL only" do
    [ nil, "", "gameble.example", "https://user:#{SECRET}@gameble.example" ].each do |public_url|
      status, output = boot_production(public_url:)

      assert_not status.success?, "#{public_url.inspect} booted: #{output}"
      assert_match(/PublicUrl::Invalid/, output)
      assert_match(/PUBLIC_URL (is not set|must be)/, output)
      assert_not_includes output, SECRET
    end
  end

  test "production boots with a valid PUBLIC_URL, normalised, and in the Docker build without one" do
    status, output = boot_production(public_url: "https://Gameble.example/")
    assert status.success?, output
    assert_equal "\"https://gameble.example\"", printed_base(output)

    status, output = boot_production(public_url: nil, dummy: "1")
    assert status.success?, output
    assert_equal "nil", printed_base(output)
  end

  test "deployment sets a valid PUBLIC_URL" do
    deploy = YAML.safe_load(Rails.root.join("config/deploy.yml").read, aliases: true)
    value = deploy.dig("env", "clear", "PUBLIC_URL")

    assert_predicate value, :present?, "config/deploy.yml must set env.clear.PUBLIC_URL"
    assert_predicate PublicUrl.parse(value), :present?
  end
end
