# frozen_string_literal: true

require "digest"
require "json"
require "time"

module RSpec
  module Sunspot
    module Profiles
      class Fingerprint
        CACHE_FORMAT_VERSION = 1

        Result = Struct.new(:fingerprint, :payload, keyword_init: true)

        class << self
          def generate(profile_name:, profile_definition:, dependencies: {}, gem_version: VERSION,
                       cache_format_version: CACHE_FORMAT_VERSION)
            payload = {
              "profile_name" => profile_name.to_s,
              "profile_definition" => normalize(profile_definition),
              "dependencies" => normalize(dependencies),
              "gem_version" => gem_version.to_s,
              "cache_format_version" => cache_format_version
            }

            Result.new(
              fingerprint: Digest::SHA256.hexdigest(JSON.generate(payload)),
              payload: payload
            )
          end

          private

          def normalize(value)
            case value
            when Hash
              value.each_with_object({}) do |(key, nested_value), normalized|
                normalized[key.to_s] = normalize(nested_value)
              end.sort.to_h
            when Array
              value.map { |element| normalize(element) }
            when Time
              value.utc.iso8601(6)
            when Symbol
              value.to_s
            else
              value
            end
          end
        end
      end
    end
  end
end
