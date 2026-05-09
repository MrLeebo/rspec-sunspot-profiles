# frozen_string_literal: true

require "bundler"
require "open3"
require "fileutils"

RSpec.describe "example Rails app integration" do
  let(:repo_root) { File.expand_path("../../../..", __dir__) }
  let(:example_root) { File.join(repo_root, "example") }
  let(:example_gemfile) { File.join(example_root, "Gemfile") }
  let(:example_cache_root) { File.join(example_root, "tmp/rspec-sunspot-profiles") }

  before(:context) do
    result = run_bundle(%w[check])
    result = run_bundle(%w[install]) unless result.fetch(:success)

    expect(result.fetch(:success)).to be(true), "example bundle setup failed:\n#{result.fetch(:output)}"
  end

  it "runs the example suite successfully" do
    run = run_example_suite
    expect(run.fetch(:success)).to be(true), run.fetch(:output)
  end

  it "improves performance when cache is enabled" do
    cold = run_example_suite(clear_cache: true)
    hot = run_example_suite
    disabled = run_example_suite(disable_cache: true, clear_cache: true)

    expect(cold.fetch(:success)).to be(true), cold.fetch(:output)
    expect(hot.fetch(:success)).to be(true), hot.fetch(:output)
    expect(disabled.fetch(:success)).to be(true), disabled.fetch(:output)

    expect(hot.fetch(:duration)).to be < (disabled.fetch(:duration) * 0.9)
    expect(cold.fetch(:duration)).to be < (disabled.fetch(:duration) * 0.95)
  end

  def run_bundle(bundle_args)
    env = base_env
    run_command(bundler_command(*bundle_args), env: env)
  end

  def run_example_suite(disable_cache: false, clear_cache: false)
    FileUtils.rm_rf(example_cache_root) if clear_cache

    env = base_env
    env["RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE"] = "1" if disable_cache

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    command = bundler_command("exec", "rspec", "--format", "progress")
    result = run_command(command, env: env)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    result.merge(duration: duration)
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
    bundler_bin_path = ENV["BUNDLE_BIN_PATH"]
    return [Gem.ruby, bundler_bin_path, *args] if bundler_bin_path

    ["bundle", *args]
  end
end
