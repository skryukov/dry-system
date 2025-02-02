# frozen_string_literal: true

require 'dry/system/constants'

module Dry
  module System
    module Plugins
      # @api private
      class Plugin
        attr_reader :name

        attr_reader :mod

        attr_reader :block

        # @api private
        def initialize(name, mod, &block)
          @name = name
          @mod = mod
          @block = block
        end

        # @api private
        def apply_to(system, options)
          system.extend(stateful? ? mod.new(options) : mod)
          system.instance_eval(&block) if block
          system
        end

        # @api private
        def load_dependencies
          Array(dependencies).each do |f|
            begin
              next if Plugins.loaded_dependencies.include?(f.to_s)

              require f
              Plugins.loaded_dependencies << f.to_s
            rescue LoadError => e
              raise PluginDependencyMissing.new(name, e.message)
            end
          end
        end

        # @api private
        def stateful?
          mod < Module
        end

        # @api private
        def dependencies
          mod.respond_to?(:dependencies) ? Array(mod.dependencies) : EMPTY_ARRAY
        end
      end

      # Register a plugin
      #
      # @param [Symbol] name The name of a plugin
      # @param [Class] plugin Plugin module
      #
      # @return [Plugins]
      #
      # @api public
      def self.register(name, plugin, &block)
        registry[name] = Plugin.new(name, plugin, &block)
      end

      # @api private
      def self.registry
        @registry ||= {}
      end

      # @api private
      def self.loaded_dependencies
        @loaded_dependencies ||= []
      end

      # Enable a plugin
      #
      # Plugin identifier
      #
      # @param [Symbol] name The plugin identifier
      # @param [Hash] options Plugin options
      #
      # @return [self]
      #
      # @api public
      def use(name, options = {})
        unless enabled_plugins.include?(name)
          plugin = Plugins.registry[name]
          plugin.load_dependencies
          plugin.apply_to(self, options)

          enabled_plugins << name
        end
        self
      end

      # @api private
      def inherited(klass)
        klass.instance_variable_set(:@enabled_plugins, enabled_plugins.dup)
        super
      end

      # @api private
      def enabled_plugins
        @enabled_plugins ||= []
      end

      require 'dry/system/plugins/bootsnap'
      register(:bootsnap, Plugins::Bootsnap)

      require 'dry/system/plugins/logging'
      register(:logging, Plugins::Logging)

      require 'dry/system/plugins/env'
      register(:env, Plugins::Env)

      require 'dry/system/plugins/notifications'
      register(:notifications, Plugins::Notifications)

      require 'dry/system/plugins/monitoring'
      register(:monitoring, Plugins::Monitoring)

      require 'dry/system/plugins/dependency_graph'
      register(:dependency_graph, Plugins::DependencyGraph)
    end
  end
end
