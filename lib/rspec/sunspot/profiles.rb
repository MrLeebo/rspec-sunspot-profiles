# frozen_string_literal: true

require_relative "profiles/version"
require_relative "profiles/fingerprint"
require_relative "profiles/cache_store"
require_relative "profiles/cache"
require_relative "profiles/configuration"
require_relative "profiles/index_capture"
require_relative "profiles/helpers"
require_relative "profiles/dsl"

module RSpec
  module Sunspot
    module Profiles
      class Error < StandardError; end

      class << self
        attr_writer :cache_bust, :configuration

        def cache_root=(value)
          configuration.cache_root = value
        end

        def cache_disabled=(value)
          configuration.cache_disabled = value
        end

        def cache_root
          configuration.cache_root
        end

        def cache_disabled?
          configuration.cache_disabled == true
        end

        def cache_bust?
          @cache_bust == true
        end

        def cache_store(root: cache_root)
          CacheStore.new(root: root)
        end

        def cache(root: cache_root, disabled: cache_disabled?, bust_cache: cache_bust?, env: ENV)
          Cache.new(
            store: cache_store(root: root),
            disabled: disabled,
            bust_cache: bust_cache,
            env: env
          )
        end

        def configuration
          @configuration ||= Configuration.new
        end

        def configure
          yield(configuration)
          install!
        end

        def define(name, data: nil, dependencies: {}, &)
          configuration.define(name, data: data, dependencies: dependencies, &)
        end

        alias register define
        alias profile define

        def apply!(example, cache_coordinator: cache)
          apply_to(example.metadata, cache_coordinator: cache_coordinator)
        end

        def apply_to(metadata = nil, cache_coordinator: cache, **metadata_keywords)
          metadata ||= metadata_keywords
          profile_names = requested_profile_names(metadata)
          return metadata if profile_names.empty?

          merged_data = initial_profile_data(metadata)
          results = {}

          profile_names.each do |profile_name|
            profile = configuration.fetch(profile_name)
            cache_result = fetch_profile(profile, cache_coordinator: cache_coordinator)

            merged_data = deep_merge(merged_data, cache_result.value)
            results[profile.name] = {
              "hit" => cache_result.hit?,
              "fingerprint" => cache_result.fingerprint,
              "miss_reason" => cache_result.miss_reason,
              "cache" => cache_result.status.to_h,
              "data" => cache_result.value
            }
          end

          metadata[configuration.names_key] = profile_names.map(&:to_s)
          metadata[configuration.data_key] = merged_data
          metadata[configuration.results_key] = results
          metadata
        end

        def cache_status(profile_name, cache_coordinator: cache)
          profile = configuration.fetch(profile_name)
          return executable_cache_status(profile) if profile.executable?

          cache_coordinator.status(
            profile_name: profile.name,
            profile_definition: profile.fingerprint_definition,
            dependencies: profile.normalized_dependencies
          ).to_h
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
          @cache_bust = nil
        end

        private

        def fetch_profile(profile, cache_coordinator:)
          if profile.executable?
            fingerprint = Fingerprint.generate(
              profile_name: profile.name,
              profile_definition: profile.fingerprint_definition,
              dependencies: profile.normalized_dependencies
            ).fingerprint

            return Cache::Result.new(
              hit?: false,
              value: IndexCapture.new.evaluate(&profile.block),
              metadata: nil,
              fingerprint: fingerprint,
              miss_reason: "executable_profile",
              status: Cache::Status.new(
                profile_name: profile.name,
                fingerprint: fingerprint,
                hit?: false,
                miss_reason: "executable_profile",
                cache_enabled: false,
                bust_cache: false,
                entry_path: nil,
                artifact_path: nil,
                artifact_exists: false,
                metadata_path: nil,
                metadata_exists: false,
                metadata: nil
              )
            )
          end

          cache_coordinator.fetch(
            profile_name: profile.name,
            profile_definition: profile.fingerprint_definition,
            dependencies: profile.normalized_dependencies,
            restore: lambda { |artifact_path, _metadata|
              JSON.parse(File.read(artifact_path))
            },
            build: lambda { |artifact_path, _payload|
              data = profile.normalized_data
              File.write(artifact_path, "#{JSON.pretty_generate(data)}\n")
              data
            }
          )
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

          Fingerprint.normalize_payload(metadata[configuration.data_key])
        end

        def executable_cache_status(profile)
          fingerprint = Fingerprint.generate(
            profile_name: profile.name,
            profile_definition: profile.fingerprint_definition,
            dependencies: profile.normalized_dependencies
          ).fingerprint

          Cache::Status.new(
            profile_name: profile.name,
            fingerprint: fingerprint,
            hit?: false,
            miss_reason: "executable_profile",
            cache_enabled: false,
            bust_cache: false,
            entry_path: nil,
            artifact_path: nil,
            artifact_exists: false,
            metadata_path: nil,
            metadata_exists: false,
            metadata: nil
          ).to_h
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
