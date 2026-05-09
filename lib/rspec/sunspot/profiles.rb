# frozen_string_literal: true

require_relative "profiles/version"
require_relative "profiles/normalization"
require_relative "profiles/configuration"
require_relative "profiles/index_capture"
require_relative "profiles/helpers"
require_relative "profiles/dsl"

module RSpec
  module Sunspot
    module Profiles
      class Error < StandardError; end

      class << self
        attr_writer :configuration

        def configuration
          @configuration ||= Configuration.new
        end

        def configure
          yield(configuration)
          install!
        end

        def define(name, data: nil, dependencies: nil, &)
          configuration.define(name, data: data, dependencies: dependencies, &)
        end

        alias register define
        alias profile define

        def apply!(example, **)
          apply_to(example.metadata, **)
        end

        def apply_to(metadata = nil, cache_coordinator: nil, **metadata_keywords)
          _cache_coordinator = cache_coordinator
          metadata ||= metadata_keywords
          profile_names = requested_profile_names(metadata)
          return metadata if profile_names.empty?

          merged_data = initial_profile_data(metadata)
          results = {}

          profile_names.each do |profile_name|
            profile = configuration.fetch(profile_name)
            profile_data = fetch_profile(profile)

            merged_data = deep_merge(merged_data, profile_data)
            results[profile.name] = {
              "type" => profile.executable? ? "executable" : "static",
              "data" => profile_data
            }
          end

          metadata[configuration.names_key] = profile_names.map(&:to_s)
          metadata[configuration.data_key] = merged_data
          metadata[configuration.results_key] = results
          metadata
        end

        def install!(rspec_config = ::RSpec.configuration)
          return unless rspec_config

          @installed_configurations ||= {}.compare_by_identity
          return rspec_config if @installed_configurations[rspec_config]

          rspec_config.include Helpers
          rspec_config.around do |example|
            ::RSpec::Sunspot::Profiles.apply!(example)
            example.run
          end

          if (path = configuration.profiles_path)
            expanded = File.expand_path(path.to_s, Dir.pwd)
            Dir[File.join(expanded, "**", "*.rb")].each { |f| require f } if File.directory?(expanded)
          end

          @installed_configurations[rspec_config] = true
          rspec_config
        end

        def reset!
          @configuration = Configuration.new
        end

        private

        def fetch_profile(profile)
          if profile.executable?
            IndexCapture.new.evaluate(&profile.block)
          else
            profile.normalized_data
          end
        end

        def requested_profile_names(metadata)
          names = []
          names.concat(Array(metadata[configuration.metadata_key])) if metadata.key?(configuration.metadata_key)

          if metadata.key?(configuration.metadata_collection_key)
            names.concat(Array(metadata[configuration.metadata_collection_key]))
          end

          names.compact.map(&:to_s).uniq
        end

        def initial_profile_data(metadata)
          return {} unless metadata.key?(configuration.data_key)

          Normalization.normalize_payload(metadata[configuration.data_key])
        end

        def deep_merge(left, right)
          if left.is_a?(Hash) && right.is_a?(Hash)
            left.merge(right) do |_key, left_value, right_value|
              deep_merge(left_value, right_value)
            end
          elsif left.is_a?(Array) && right.is_a?(Array)
            left + right
          else
            right
          end
        end
      end
    end
  end
end
