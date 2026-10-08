require "rake"

# The application's Rake tasks in a test: loaded once per process, the first
# time a test asks for one. Call it in `setup`, outside any capture_io: in a
# full run `bin/rails test` has already loaded the .rake files for its
# test:prepare (in a Rake application of its own, so no task is defined
# here) and loads them again here. A .rake file defines no constant, or
# that second load warns on stderr: a class a task needs lives beside
# lib/tasks and is required by the task (packs/game/lib/open_pack_benchmark.rb).
#
#   setup { rake_task("game:top_up_banks") }
#   rake_task("game:top_up_banks").execute
module RakeTasks
  def rake_task(name)
    Rails.application.load_tasks unless Rake::Task.task_defined?(name)
    Rake::Task[name]
  end
end
