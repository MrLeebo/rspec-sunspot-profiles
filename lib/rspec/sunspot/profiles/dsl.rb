# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      module DSL
        private

        def profile(name, **, &)
          ::RSpec::Sunspot::Profiles.define(name, **, &)
        end
      end
    end
  end
end

Kernel.include(RSpec::Sunspot::Profiles::DSL)
