# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module RSpec
  module Sunspot
    module Profiles
      class CacheStore
        ARTIFACT_FILENAME = "artifact"
        METADATA_FILENAME = "metadata.json"

        attr_reader :root

        def initialize(root:)
          @root = File.expand_path(root.to_s)
        end

        def entry_path(profile_name:)
          File.join(root, sanitize(profile_name))
        end

        def artifact_path(profile_name:)
          File.join(entry_path(profile_name: profile_name), ARTIFACT_FILENAME)
        end

        def metadata_path(profile_name:)
          File.join(entry_path(profile_name: profile_name), METADATA_FILENAME)
        end

        def prepare(profile_name:)
          FileUtils.mkdir_p(entry_path(profile_name: profile_name))
        end

        def artifact_exist?(profile_name:)
          File.file?(artifact_path(profile_name: profile_name))
        end

        def metadata_for(profile_name:)
          path = metadata_path(profile_name: profile_name)
          return unless File.file?(path)

          JSON.parse(File.read(path))
        end

        def write_metadata(profile_name:, fingerprint_result:)
          prepare(profile_name: profile_name)

          metadata = {
            "profile_name" => profile_name.to_s,
            "fingerprint" => fingerprint_result.fingerprint,
            "cache_format_version" => fingerprint_result.payload.fetch("cache_format_version"),
            "created_at" => Time.now.utc.iso8601,
            "hashed_inputs" => fingerprint_result.payload
          }

          File.write(metadata_path(profile_name: profile_name), "#{JSON.pretty_generate(metadata)}\n")
          metadata
        end

        def clear(profile_name:)
          FileUtils.rm_rf(entry_path(profile_name: profile_name))
        end

        private

        def sanitize(profile_name)
          sanitized = profile_name.to_s.strip.gsub(%r{[^A-Za-z0-9._-]+}, "-")
          sanitized = sanitized.delete_prefix("-").delete_suffix("-")
          sanitized.empty? ? "profile" : sanitized
        end
      end
    end
  end
end
