# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      class Configuration
        Profile = Struct.new(:name, :data, :dependencies, keyword_init: true) do
          def normalized_data
            Fingerprint.normalize_payload(data)
          end

          def normalized_dependencies
            Fingerprint.normalize_payload(dependencies || {})
          end
        end

        attr_accessor :metadata_key, :metadata_collection_key, :data_key, :results_key, :names_key

        def initialize
          @metadata_key = :sunspot_profile
          @metadata_collection_key = :sunspot_profiles
          @data_key = :sunspot_profile_data
          @results_key = :sunspot_profile_results
          @names_key = :sunspot_profile_names
          @profiles = {}
        end

        def define(name, data:, dependencies: {})
          profile = Profile.new(
            name: name.to_s,
            data: data,
            dependencies: dependencies
          )

          @profiles[profile.name] = profile
        end

        alias register define

        def fetch(name)
          @profiles.fetch(name.to_s) do
            raise Error, "unknown sunspot profile: #{name}"
          end
        end

        def profiles
          @profiles.dup
        end
      end
    end
  end
end
