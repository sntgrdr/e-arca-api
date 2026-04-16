# This rake task was added by annotaterb gem.
# Keeps model annotations in sync after every db:migrate / db:rollback.
# Set ANNOTATERB_SKIP_ON_DB_TASKS=1 to skip (e.g. in CI).

if Rails.env.development? && ENV["ANNOTATERB_SKIP_ON_DB_TASKS"].nil?
  require "annotate_rb"

  AnnotateRb::Core.load_rake_tasks
end
