# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Boundaries: Packwerk", "bundle exec packwerk validate && bundle exec packwerk check"
  step "Translations: missing keys", "bundle exec i18n-tasks missing"
  step "Types: TypeScript", "npm run typecheck"
  step "Markup: built by the server", "script/check_markup_apis"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Migrations: build db/schema.rb", "rm -f tmp/migrated_schema.rb && env RAILS_ENV=test SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && diff -u db/schema.rb tmp/migrated_schema.rb"
  step "Migrations: db/schema.rb round trip", "env RAILS_ENV=test bin/rails db:drop db:create db:schema:load db:schema:dump && git diff --exit-code -- db/schema.rb"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
