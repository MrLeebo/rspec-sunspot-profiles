# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      class Cache
        DISABLE_ENV = "RSPEC_SUNSPOT_PROFILES_CACHE_DISABLE"
        BUST_ENV = "RSPEC_SUNSPOT_PROFILES_CACHE_BUST"

        Result = Struct.new(:hit?, :value, :metadata, :fingerprint, :miss_reason, :status, keyword_init: true)
        Status = Struct.new(
          :profile_name, :fingerprint, :hit?, :miss_reason, :cache_enabled, :bust_cache,
          :entry_path, :artifact_path, :artifact_exists, :metadata_path, :metadata_exists, :metadata,
          keyword_init: true
        ) do
          def to_h
            {
              "profile_name" => profile_name,
              "fingerprint" => fingerprint,
              "hit" => hit?,
              "miss_reason" => miss_reason,
              "cache_enabled" => cache_enabled,
              "bust_cache" => bust_cache,
              "entry_path" => entry_path,
              "artifact_path" => artifact_path,
              "artifact_exists" => artifact_exists,
              "metadata_path" => metadata_path,
              "metadata_exists" => metadata_exists,
              "fingerprint_matches" => fingerprint_matches?,
              "existing_fingerprint" => existing_fingerprint,
              "metadata" => metadata
            }
          end

          def fingerprint_matches?
            existing_fingerprint == fingerprint
          end

          def existing_fingerprint
            metadata&.fetch("fingerprint", nil)
          end
        end

        def initialize(store:, disabled: false, bust_cache: false, env: ENV)
          @store = store
          @disabled = disabled
          @bust_cache = bust_cache
          @env = env
        end

        def status(profile_name:, profile_definition:, dependencies: {}, gem_version: VERSION,
                   cache_format_version: Fingerprint::CACHE_FORMAT_VERSION)
          fingerprint_result = Fingerprint.generate(
            profile_name: profile_name,
            profile_definition: profile_definition,
            dependencies: dependencies,
            gem_version: gem_version,
            cache_format_version: cache_format_version
          )

          metadata = store.metadata_for(profile_name: profile_name)
          artifact_exists = store.artifact_exist?(profile_name: profile_name)
          metadata_exists = !metadata.nil?
          cache_enabled = cache_enabled?
          bust_cache = bust_cache?
          hit = cache_enabled &&
                !bust_cache &&
                metadata_exists &&
                artifact_exists &&
                metadata.fetch("fingerprint", nil) == fingerprint_result.fingerprint

          miss_reason = if hit
                          nil
                        else
                          miss_reason_for(
                            cache_enabled: cache_enabled,
                            bust_cache: bust_cache,
                            metadata_exists: metadata_exists,
                            artifact_exists: artifact_exists,
                            fingerprint_matches: metadata&.fetch("fingerprint", nil) == fingerprint_result.fingerprint
                          )
                        end

          Status.new(
            profile_name: profile_name.to_s,
            fingerprint: fingerprint_result.fingerprint,
            hit?: hit,
            miss_reason: miss_reason,
            cache_enabled: cache_enabled,
            bust_cache: bust_cache,
            entry_path: store.entry_path(profile_name: profile_name),
            artifact_path: store.artifact_path(profile_name: profile_name),
            artifact_exists: artifact_exists,
            metadata_path: store.metadata_path(profile_name: profile_name),
            metadata_exists: metadata_exists,
            metadata: metadata
          )
        end

        def fetch(
          profile_name:, profile_definition:, restore:, build:, dependencies: {}, gem_version: VERSION,
          cache_format_version: Fingerprint::CACHE_FORMAT_VERSION
        )
          cache_status = status(
            profile_name: profile_name,
            profile_definition: profile_definition,
            dependencies: dependencies,
            gem_version: gem_version,
            cache_format_version: cache_format_version
          )

          if cache_status.hit?
            return Result.new(
              hit?: true,
              value: restore.call(store.artifact_path(profile_name: profile_name), cache_status.metadata),
              metadata: cache_status.metadata,
              fingerprint: cache_status.fingerprint,
              miss_reason: nil,
              status: cache_status
            )
          end

          fingerprint_result = Fingerprint::Result.new(
            fingerprint: cache_status.fingerprint,
            payload: fingerprint_payload(
              profile_name: profile_name,
              profile_definition: profile_definition,
              dependencies: dependencies,
              gem_version: gem_version,
              cache_format_version: cache_format_version
            )
          )

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
            fingerprint: fingerprint_result.fingerprint,
            miss_reason: cache_status.miss_reason,
            status: cache_status
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

        def fingerprint_payload(profile_name:, profile_definition:, dependencies:, gem_version:, cache_format_version:)
          Fingerprint.generate(
            profile_name: profile_name,
            profile_definition: profile_definition,
            dependencies: dependencies,
            gem_version: gem_version,
            cache_format_version: cache_format_version
          ).payload
        end

        def ensure_artifact_written!(profile_name:)
          return if store.artifact_exist?(profile_name: profile_name)

          raise Error, "build callback must write #{store.artifact_path(profile_name: profile_name)}"
        end

        def truthy?(value)
          %w[1 true yes on].include?(value.to_s.downcase)
        end

        def miss_reason_for(cache_enabled:, bust_cache:, metadata_exists:, artifact_exists:, fingerprint_matches:)
          return "cache_disabled" unless cache_enabled
          return "cache_busted" if bust_cache
          return "missing_metadata" unless metadata_exists
          return "missing_artifact" unless artifact_exists
          return "fingerprint_changed" unless fingerprint_matches

          nil
        end
      end
    end
  end
end
