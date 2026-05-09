# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      class Cache
        DISABLE_ENV = "RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE"
        BUST_ENV = "RSPEC_SUNSPOT_PROFILES_CACHE_BUST"

        Result = Struct.new(:hit?, :value, :metadata, :fingerprint, keyword_init: true)

        def initialize(store:, disabled: false, bust_cache: false, env: ENV)
          @store = store
          @disabled = disabled
          @bust_cache = bust_cache
          @env = env
        end

        def fetch(profile_name:, profile_definition:, restore:, build:, dependencies: {}, gem_version: VERSION,
                  cache_format_version: Fingerprint::CACHE_FORMAT_VERSION)
          fingerprint_result = Fingerprint.generate(
            profile_name: profile_name,
            profile_definition: profile_definition,
            dependencies: dependencies,
            gem_version: gem_version,
            cache_format_version: cache_format_version
          )

          if cache_hit?(profile_name: profile_name, fingerprint: fingerprint_result.fingerprint)
            metadata = store.metadata_for(profile_name: profile_name)

            return Result.new(
              hit?: true,
              value: restore.call(store.artifact_path(profile_name: profile_name), metadata),
              metadata: metadata,
              fingerprint: fingerprint_result.fingerprint
            )
          end

          store.prepare(profile_name: profile_name)
          value = build.call(store.artifact_path(profile_name: profile_name), fingerprint_result.payload)

          metadata = if cache_enabled?
                       ensure_artifact_written!(profile_name: profile_name)
                       store.write_metadata(profile_name: profile_name, fingerprint_result: fingerprint_result)
                     end

          Result.new(
            hit?: false,
            value: value,
            metadata: metadata,
            fingerprint: fingerprint_result.fingerprint
          )
        end

        def cache_enabled?
          !(@disabled || truthy?(env[DISABLE_ENV]))
        end

        def bust_cache?
          @bust_cache || truthy?(env[BUST_ENV])
        end

        private

        attr_reader :store, :env

        def cache_hit?(profile_name:, fingerprint:)
          return false unless cache_enabled?
          return false if bust_cache?

          metadata = store.metadata_for(profile_name: profile_name)
          return false unless metadata
          return false unless store.artifact_exist?(profile_name: profile_name)

          metadata["fingerprint"] == fingerprint
        end

        def ensure_artifact_written!(profile_name:)
          return if store.artifact_exist?(profile_name: profile_name)

          raise Error, "build callback must write #{store.artifact_path(profile_name: profile_name)}"
        end

        def truthy?(value)
          %w[1 true yes on].include?(value.to_s.downcase)
        end
      end
    end
  end
end
