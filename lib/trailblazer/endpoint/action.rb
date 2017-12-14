module Trailblazer
  # This module currently does nothing and is only here for consistent syntax.
  module Endpoint::Action
    module DSL
      def action(name)
        actions[name] = true
      end

      # @private
      def actions
        @actions ||= {}
      end
    end

    def self.included(includer)
      includer.extend(DSL)
    end
  end
end
