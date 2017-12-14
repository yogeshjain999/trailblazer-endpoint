module Trailblazer
  module Endpoint
    def self.call(operation, *args)
      result = operation.(*args)

      Matcher.(result)
    end
  end
end

require "trailblazer/endpoint/matcher"
require "trailblazer/endpoint/pattern"
require "trailblazer/endpoint/action"
