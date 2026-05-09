# frozen_string_literal: true

module RSpec
  module Sunspot
    module Profiles
      module DSL
        private

        def profile(name, **options, &block)
          ::RSpec::Sunspot::Profiles.define(name, **options, &block)
        end
      end
    end
  end
end

Kernel.include(RSpec::Sunspot::Profiles::DSL)
