module Trailblazer
  module Endpoint::Pattern
    module DSL
      def pattern(name)
        patterns[name] = true
      end

      # @private
      def patterns
        @patterns ||= {}
      end
    end

    def self.included(includer)
      includer.extend(DSL)
    end

    # Convert to pattern hash.
    def to_h
      ary = self.class.patterns.collect { |name, _| [name, method(name)] }
      Hash[ary]
    end
  end
end
