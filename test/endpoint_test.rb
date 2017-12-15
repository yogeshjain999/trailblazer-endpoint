require "test_helper"

require "trailblazer/endpoint"

class EndpointTest < Minitest::Spec
  it do

    patterns = Class.new do
      include Trailblazer::Endpoint::Pattern

      # a pattern method always receives everything after the first arg passed to `Match.()`
      #   Match.( [your config], result, some: config, you: want )

      pattern def success_with_block?(result, **options, &block)
        result.success? && block_given?
      end

      pattern def new_success?(result, hint:, **, &block)
        result.success? && hint == :new # this is just my "style"
      end

      pattern def update_failure?(result, hint:, **, &block)
        result.failure? && hint == :update
      end

      # It is possible to have other methods in your patterns that help keeping it DRY.
      def some_other_method_that_should_be_ignored # this method is not a pattern.
      end
    end

    # we now have the patterns (or rules) comiled, we can use inheritance, etc.
    patterns.new.to_h.keys.must_equal [:success_with_block?, :new_success?, :update_failure?]

    # here, you can use a module and Rails API, or you can stay strict and only delegate to representers, etc.
    MyActions = actions = Module.new do
      include Trailblazer::Endpoint::Action

      action def yield_block(result, &block)
        yield(result)
      end

      action def _render(result, some_default_option: "Bootstrap", hint:)
        "#{self.class} #{hint} #{result.success?}"
      end
    end


    class MyController
      include MyActions
    end

require "trailblazer/option"



    patterns = patterns.new.to_h

    matcher_cfg = {
      patterns[:success_with_block?]  => Trailblazer::Option(:yield_block),
      patterns[:update_failure?]      => Trailblazer::Option(:_render),
    }

    result = Struct.new(:success?).new(true) # run operation.

    matcher = Trailblazer::Endpoint::Matcher.new(matcher_cfg)

    matcher.( {exec_context: MyController.new}, result ) do |result|
      "success! #{result.success?.inspect}"
    end.must_equal "success! true"

    result = Struct.new(:success?, :failure?).new(false, true) # run operation.

    matcher.( { exec_context: MyController.new }, result, hint: :update ) do |result|
      "success! #{result.success?.inspect}"
    end.must_equal "EndpointTest::MyController update false"
  end
end
