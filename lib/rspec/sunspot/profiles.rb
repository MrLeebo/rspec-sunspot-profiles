# frozen_string_literal: true

require_relative "profiles/version"
require_relative "profiles/fingerprint"
require_relative "profiles/cache_store"
require_relative "profiles/cache"

module RSpec
  module Sunspot
    module Profiles
      class Error < StandardError; end

      class << self
        attr_writer :cache_root, :cache_disabled, :cache_bust

        def cache_root
          @cache_root ||= File.expand_path("tmp/rspec-sunspot-profiles", Dir.pwd)
        end

        def cache_disabled?
          @cache_disabled == true
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
      end
    end
  end
end
