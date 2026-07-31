# frozen_string_literal: true

require_relative "lib/segue/version"

Gem::Specification.new do |spec|
  spec.name = "segue"
  spec.version = Segue::VERSION
  spec.authors = ["Mark Ryall"]
  spec.email = ["mark@ryall.name"]

  spec.summary = "Crossfading queue daemon for mpv"
  spec.homepage = "https://github.com/markryall/segue"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == File.basename(__FILE__)) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|jj|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "curses"
  spec.add_dependency "rainbow"
  # No longer a default gem as of ruby 4.0 - the scrobbler parses last.fm's xml
  spec.add_dependency "rexml"
end
