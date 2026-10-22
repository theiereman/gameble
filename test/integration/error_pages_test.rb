require "test_helper"
require "open3"
require "tmpdir"

# The static error pages in public/, one per status and locale, hold no
# inline style or script, which the enforced Content-Security-Policy would
# block, and load only files from public/, stamped so a changed file gets a
# new URL past public/'s year-long cache.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  OLD_BROWSER = "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko"
  PAGES = %w[400 404 406-unsupported-browser 422 500].product(%w[en fr]).map { |name, locale| "#{name}.#{locale}.html" }.freeze
  COPIES = {
    "vt323-latin-400-normal.woff2" => "app/frontend/fonts",
    "jetbrains-mono-latin-400-normal.woff2" => "app/frontend/fonts",
    "jetbrains-mono-latin-700-normal.woff2" => "app/frontend/fonts",
    "OFL-VT323.txt" => "app/frontend/fonts",
    "OFL-JetBrainsMono.txt" => "app/frontend/fonts",
    "wordmark.svg" => "app/frontend/images/pixel",
    "starfield.svg" => "app/frontend/images/pixel"
  }.freeze
  HOME_LABELS = { "en" => "BACK TO HOME", "fr" => "RETOUR À L'ACCUEIL" }.freeze

  test "the error pages are 400, 404, 406, 422 and 500, in English and French" do
    assert_equal PAGES.sort, Rails.public_path.glob("*.html").map { it.basename.to_s }.sort
  end

  PAGES.each do |page|
    test "#{page} holds no style or script, and links home in its language" do
      html = Nokogiri::HTML(Rails.public_path.join(page).read)
      locale = page[/\.(\w+)\.html\z/, 1]

      assert_empty html.css("style, [style], script")
      assert_equal locale, html.at_css("html")["lang"]
      assert_match(/gameble/, html.at_css("title").text)
      assert_equal [ "/#{locale}" ], html.css("a.error__home").map { it["href"] }
      assert_equal HOME_LABELS[locale], html.at_css("a.error__home").text
      assert_equal [ "/errors.css?v=#{stamp("errors.css")}" ], html.css("link[rel=stylesheet]").map { it["href"] }
    end
  end

  test "every asset the pages and the stylesheet link is under public/ and its stamp matches its file" do
    urls = PAGES.flat_map { Rails.public_path.join(it).read.scan(%r{(?:href|src)="(/errors[^"]*)"}).flatten } +
      Rails.public_path.join("errors.css").read.scan(/url\("([^"]+)"\)/).flatten

    assert_equal 6, urls.uniq.size
    urls.uniq.each do |url|
      path, version = url.split("?v=")

      assert_path_exists Rails.public_path.join(path.delete_prefix("/")), url
      assert_equal stamp(path.delete_prefix("/")), version, url
    end
  end

  test "the copies in public/errors/ match their sources" do
    assert_equal COPIES.keys.sort, Rails.public_path.join("errors").children.map { it.basename.to_s }.sort
    COPIES.each do |file, source|
      assert_equal Rails.root.join(source, file).binread, Rails.public_path.join("errors", file).binread, file
    end
  end

  test "the build script finds nothing to change" do
    output, status = build("--check")

    assert_predicate status, :success?, output
  end

  test "the build script's check fails once a source changes, until the script runs" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/frontend"))
      FileUtils.cp_r(Rails.root.join("app/frontend/fonts"), File.join(dir, "app/frontend"))
      FileUtils.mkdir_p(File.join(dir, "app/frontend/images/pixel"))
      %w[wordmark.svg starfield.svg].each { FileUtils.cp(Rails.root.join("app/frontend/images/pixel", it), File.join(dir, "app/frontend/images/pixel")) }
      FileUtils.mkdir_p(File.join(dir, "public"))
      FileUtils.cp_r(Rails.public_path.glob("{*.html,errors.css,errors}"), File.join(dir, "public"))
      File.write(File.join(dir, "app/frontend/images/pixel/starfield.svg"), "<svg/>")

      output, status = build("--check", "--root", dir)
      assert_not_predicate status, :success?, output
      assert_match %r{differs: public/errors/starfield.svg}, output
      assert_match %r{differs: public/errors.css}, output

      build("--root", dir)
      output, status = build("--check", "--root", dir)
      assert_predicate status, :success?, output
      assert_includes File.read(File.join(dir, "public/errors.css")), "/errors/starfield.svg?v=#{Digest::SHA256.hexdigest("<svg/>")[0, 8]}"
    end
  end

  test "the stylesheet is served from public/" do
    get "/errors.css"

    assert_response :success
    assert_equal "text/css", response.media_type
  end

  test "an unknown address under /fr gets the French 404 page, without a policy header" do
    without_detailed_exceptions { get "/fr/no-such-page" }

    assert_response :not_found
    assert_nil response.headers["Content-Security-Policy"]
    assert_error_page "fr", "PAGE INTROUVABLE"
    assert_select "style", false
  end

  test "the path's locale wins over the browser's" do
    without_detailed_exceptions { get "/en/no-such-page", headers: { "Accept-Language" => "fr" } }

    assert_response :not_found
    assert_error_page "en", "PAGE NOT FOUND"
  end

  test "an address without a locale gets the browser's language" do
    without_detailed_exceptions { get "/no-such-page", headers: { "Accept-Language" => "fr-FR" } }

    assert_response :not_found
    assert_error_page "fr", "PAGE INTROUVABLE"
  end

  test "an address without a locale, from a browser asking for no known language, gets the default locale" do
    without_detailed_exceptions { get "/no-such-page", headers: { "Accept-Language" => "de-DE" } }
    assert_error_page "en", "PAGE NOT FOUND"

    without_detailed_exceptions { get "/no-such-page" }
    assert_error_page "en", "PAGE NOT FOUND"
  end

  test "an action that raises under /en gets the English 500 page" do
    original = Accounts::PlayerById.method(:call)
    Accounts::PlayerById.define_singleton_method(:call) { |*| raise "broken" }
    begin
      without_detailed_exceptions(show_exceptions: :all) { get home_path(locale: :en) }
    ensure
      Accounts::PlayerById.define_singleton_method(:call, original)
    end

    assert_response :internal_server_error
    assert_error_page "en", "SERVER ERROR"
  end

  test "an old browser on a page not meant to be shared gets the 406 page in its locale under the enforced policy" do
    get more_path(locale: :fr), headers: { "User-Agent" => OLD_BROWSER }

    assert_response :not_acceptable
    assert_predicate response.headers["Content-Security-Policy"], :present?
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_error_page "fr", "NAVIGATEUR NON PRIS EN CHARGE"
    assert_select "style", false
    assert_select "[style]", false
    assert_select "script", false
  end

  test "the enforced policy lets the 406 page load its stylesheet, fonts and images from its own origin" do
    get home_path(locale: :en), headers: { "User-Agent" => OLD_BROWSER }

    policy = response.headers["Content-Security-Policy"].split(";").to_h { it.strip.split(" ", 2) }

    %w[style-src font-src img-src].each { assert_includes policy[it], "'self'" }
  end

  private
    def stamp(public_file)
      Digest::SHA256.file(Rails.public_path.join(public_file)).hexdigest[0, 8]
    end

    def build(*args)
      Open3.capture2e("node", "script/error_pages/build.mjs", *args, chdir: Rails.root.to_s)
    end

    def assert_error_page(locale, label)
      assert_select "html[lang=?]", locale
      assert_select "h1.error__label", label
      assert_select "a.error__home[href=?]", "/#{locale}"
      assert_select "link[rel=stylesheet][href=?]", "/errors.css?v=#{stamp("errors.css")}"
    end

    def without_detailed_exceptions(show_exceptions: nil)
      env_config = Rails.application.env_config
      saved = env_config.slice("action_dispatch.show_detailed_exceptions", "action_dispatch.show_exceptions")
      env_config["action_dispatch.show_detailed_exceptions"] = false
      env_config["action_dispatch.show_exceptions"] = show_exceptions if show_exceptions
      yield
    ensure
      env_config.merge!(saved)
    end
end
