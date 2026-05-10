# frozen_string_literal: true

require_relative "lib/rspec/sunspot/profiles/version"

Gem::Specification.new do |spec|
  spec.name = "rspec-sunspot-profiles"
  spec.version = RSpec::Sunspot::Profiles::VERSION
  spec.authors = ["MrLeebo contributors"]
  spec.email = ["noreply@example.com"]

  spec.summary = "Reusable Sunspot profile helpers for RSpec test runs."
  spec.description = "Provides named static and executable Sunspot profiles that can be applied to RSpec examples."
  spec.homepage = "https://github.com/MrLeebo/rspec-sunspot-profiles"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |file|
      file == gemspec || file.start_with?("bin/", ".git/")
    end
  end

  spec.bindir = "exe"
  spec.executables = []
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", ">= 3.13", "< 4"
end
