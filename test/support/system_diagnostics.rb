# What a failed system test saw, written beside its screenshot, and with
# SYSTEM_TIMINGS=1 how long each test took (tmp/system_timings.tsv).
module SystemDiagnostics
  LOG = Rails.root.join("log/test.log")
  REQUEST_LINE = /\A(Started |Completed |Processing by |.*(Error|Exception))/
  PAGE_TEXT_LENGTH = 2000
  REQUEST_LINES = 80

  def before_setup
    @log_offset = LOG.exist? ? LOG.size : 0
    @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    super
  end

  def before_teardown
    write_failure_diagnostics if failed?
    append_timing if ENV["SYSTEM_TIMINGS"]
    super
  end

  private

  def write_failure_diagnostics
    path = Rails.root.join("tmp/screenshots/#{name.parameterize}.diagnostics.txt")
    FileUtils.mkdir_p(path.dirname)
    path.write(diagnostics)
    puts "[Diagnostics]: #{path}"
  rescue StandardError => error
    puts "[Diagnostics]: not written (#{error.class}: #{error.message})"
  end

  def diagnostics
    <<~TEXT
      url: #{seen { page.current_url }}
      title: #{seen { page.title }}

      -- page text (first #{PAGE_TEXT_LENGTH} characters)
      #{seen { page.text.to_s[0, PAGE_TEXT_LENGTH] }}

      -- browser console
      #{seen { page.driver.browser.logs.get(:browser).map { "#{it.level} #{it.message}" }.join("\n") }}

      -- server requests during the test (last #{REQUEST_LINES}, both workers' servers mixed)
      #{seen { requests_during_the_test }}
    TEXT
  end

  def requests_during_the_test
    chunk = LOG.open { |file| file.seek(@log_offset) && file.read }.to_s.scrub
    chunk.lines.grep(REQUEST_LINE).last(REQUEST_LINES).map { it.strip[0, 200] }.join("\n")
  end

  def seen
    yield
  rescue StandardError => error
    "unavailable (#{error.class}: #{error.message[0, 120]})"
  end

  def append_timing
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
    File.open(Rails.root.join("tmp/system_timings.tsv"), "a") { it.puts [ elapsed.round(2), self.class.name, name ].join("\t") }
  end
end
