# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      module Helpers
        def sunspot_profile_names
          current_sunspot_metadata[Profiles.configuration.names_key] || []
        end

        def sunspot_profile_data
          current_sunspot_metadata[Profiles.configuration.data_key]
        end

        def sunspot_profile_results
          current_sunspot_metadata[Profiles.configuration.results_key] || {}
        end

        private

        def current_sunspot_metadata
          example = ::RSpec.respond_to?(:current_example) ? ::RSpec.current_example : nil
          example ? example.metadata : {}
        end
      end
    end
  end
end
