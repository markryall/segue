# frozen_string_literal: true

require "tmpdir"
require "segue"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Never let a spec touch the real ~/.segue
  config.around(:each, :sandboxed) do |example|
    Dir.mktmpdir("segue-spec") do |dir|
      original = ENV.fetch("SEGUE_HOME", nil)
      ENV["SEGUE_HOME"] = dir
      begin
        example.run
      ensure
        ENV["SEGUE_HOME"] = original
      end
    end
  end
end
