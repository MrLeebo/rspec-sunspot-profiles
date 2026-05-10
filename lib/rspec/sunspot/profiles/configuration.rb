# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      class Configuration
        Profile = Struct.new(:name, :block, :shared, keyword_init: true) do
          def executable?
            !block.nil?
          end

          def shared?
            !!shared
          end
        end

        attr_accessor :profiles_path, :metadata_key, :metadata_collection_key, :data_key, :results_key, :names_key

        def initialize
          @profiles_path = "spec/data_profiles"
          @metadata_key = :sunspot_profile
          @metadata_collection_key = :sunspot_profiles
          @data_key = :sunspot_profile_data
          @results_key = :sunspot_profile_results
          @names_key = :sunspot_profile_names
          @profiles = {}
          @profile_cache = {}
        end

        def profile_cached?(name)
          @profile_cache.key?(name.to_s)
        end

        def cached_profile_data(name)
          @profile_cache[name.to_s]
        end

        def cache_profile_data(name, data)
          @profile_cache[name.to_s] = data
        end

        def define(name, shared: false, &block)
          validate_definition!(name, block)

          profile = Profile.new(
            name: name.to_s,
            block: block,
            shared: shared
          )

          raise Error, "sunspot profile already registered: #{profile.name}" if @profiles.key?(profile.name)

          @profiles[profile.name] = profile
        end

        alias register define
        alias profile define

        def fetch(name)
          @profiles.fetch(name.to_s) do
            raise Error, "unknown sunspot profile: #{name}"
          end
        end

        def profiles
          @profiles.dup
        end

        private

        def validate_definition!(name, block)
          return if block

          raise ArgumentError, "profile #{name} must be defined with a block"
        end
      end
    end
  end
end
