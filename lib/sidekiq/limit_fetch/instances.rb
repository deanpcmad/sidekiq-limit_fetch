# frozen_string_literal: true

module Sidekiq
  module LimitFetch
    module Instances
      def self.extended(klass)
        klass.instance_variable_set :@instances, {}
      end

      def new(*args)
        @instances[args] ||= super
      end

      alias [] new

      def instances
        @instances.values
      end

      def reset_instances!
        @instances = {}
      end

      def delete_instance(name)
        @instances.delete [name]
      end
    end
  end
end
