# frozen_string_literal: true

require "bundler"
require "open3"

RSpec.describe "example Rails app integration" do
  before(:context) do
    result = run_bundle(%w[check])
    result = run_bundle(%w[install]) unless result.fetch(:success)

    expect(result.fetch(:success)).to be(true), "example bundle setup failed:\n#{result.fetch(:output)}"
  end

  it "runs the example suite successfully" do
    run = run_example_suite
    expect(run.fetch(:success)).to be(true), run.fetch(:output)
  end

  def run_bundle(bundle_args)
    env = base_env
    run_command(bundler_command(*bundle_args), env: env)
  end

  def run_example_suite
    env = base_env
    command = bundler_command("exec", "rspec", "--format", "progress")
    run_command(command, env: env)
  end

  def run_command(command, env:)
    output = +""
    success = false

    Bundler.with_unbundled_env do
      stdout, stderr, status = Open3.capture3(env, *command, chdir: example_root)
      output << stdout
      output << stderr
      success = status.success?
    end

    { success: success, output: output }
  end

  def base_env
    {
      "BUNDLE_GEMFILE" => example_gemfile,
      "BUNDLE_PATH" => File.join(example_root, "vendor/bundle"),
      "RAILS_ENV" => "test"
    }
  end

  def bundler_command(*args)
    bundler_bin_path = ENV.fetch("BUNDLE_BIN_PATH", nil)
    return [Gem.ruby, bundler_bin_path, *args] if bundler_bin_path

    ["bundle", *args]
  end

  def example_root
    File.join(repo_root, "example")
  end

  def example_gemfile
    File.join(example_root, "Gemfile")
  end

  def repo_root
    File.expand_path("../../..", __dir__)
  end
end
