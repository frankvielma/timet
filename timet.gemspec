# frozen_string_literal: true

require_relative "lib/timet/version"

Gem::Specification.new do |spec|
  spec.name = "timet"
  spec.version = Timet::VERSION
  spec.authors = ["Frank Vielma"]
  spec.email = ["frankvielma@gmail.com"]

  spec.summary = "Command line time tracker with reports"
  spec.description = "Timet is a command-line time tracker that keeps track of your activities." 
  spec.homepage = "https://frankvielma.github.io/posts/timet-a-powerful-command-line-tool-for-tracking-your-time/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"
  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "tty-prompt", "~> 0.2"
  spec.add_dependency "sqlite3", "~> 2", ">= 1.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/frankvielma/timet"
  spec.metadata["changelog_uri"] = "https://github.com/frankvielma/timet/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/timet"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["timet"]
  spec.require_paths = ["lib"]

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
