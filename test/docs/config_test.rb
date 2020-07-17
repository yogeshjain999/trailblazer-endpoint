require "test_helper"

# TODO
# extend empty conf methods instead of {respond_to?}
module Trailblazer
  class Endpoint
    def self.Normalizer(target:, methods:)
      normalizer = Class.new(Trailblazer::Activity::Railway) do
        methods.collect do |config_name|
          step Normalizer::Default.new(config_name), id: :"default_#{config_name}"
        end
      end

      normalizer = Normalizer.add(normalizer, target, methods) # {target} is the "target class".

      Normalizer::State.new(normalizer, methods)
    end

    module Normalizer
      class Default
        def initialize(config_name)
          @config_name = config_name
        end

        def call(ctx, **)
          ctx[@config_name] ||= {}
        end
      end

      class State < Module
        def initialize(normalizer, config)
          @normalizer = normalizer
          @config = config
        end

        # called once when extended in {ApplicationController}.
        def extended(extended)
          super
          extended.extend(Accessor)
          extended.extend(Config)
          extended.instance_variable_set(:@normalizer, @normalizer)
          extended.instance_variable_set(:@config, @config)
        end

      end
      module Accessor
        def inherited(subclass)
          normalizer = Normalizer.add(_normalizer, subclass, _config) # add configure steps for {subclass} to the _new_ normalizer.
          subclass.instance_variable_set(:@normalizer, normalizer)
          subclass.instance_variable_set(:@config, _config)
        end

        def _normalizer
          @normalizer
        end
      end


      module Config
        # @experimental
        def config=(v)
          @config = v
        end
        def _config
          @config
        end
      end

      def self.add(normalizer, target, methods)
        Class.new(normalizer) do
          methods.collect do |config_name|
            step task: Normalizer.CallDirectiveMethod(target, config_name), id: "#{target}##{config_name}"
          end
        end
      end

      def self.CallDirectiveMethod(target, config_name)
        ->((ctx, flow_options), *) {

          if target.respond_to?(config_name) # this is pure magic, kinda sucks, but for configuration is ok. # TODO: add flag {strict: true}.
            config = target.send(config_name, ctx, **ctx)
            ctx[config_name] = ctx[config_name].merge(config)
          end

          return Trailblazer::Activity::Right, [ctx, flow_options]
        }
      end
    end # Normalizer
  end
end

class ConfigTest < Minitest::Spec
  Controller = Struct.new(:params)

  class ApplicationController
    # extend Trailblazer::Endpoint.Normalizer(methods: [:options_for_endpoint, :options_for_domain_ctx])
    # extend Trailblazer::Endpoint::Normalizer::Bla
    extend Trailblazer::Endpoint.Normalizer(target: self, methods: [:options_for_endpoint, :options_for_domain_ctx])

    def self.options_for_endpoint(ctx, **)
      {
        find_process_model: true,
      }
    end
  end

  it "what" do
    puts Trailblazer::Developer.render(ApplicationController._normalizer)
    signal, (ctx, ) = Trailblazer::Developer.wtf?( ApplicationController._normalizer, [{}])
    pp ctx

    ctx.inspect.must_equal %{{:options_for_endpoint=>{:find_process_model=>true}, :options_for_domain_ctx=>{}}}

    puts Trailblazer::Developer.render(MemoController._normalizer)
    signal, (ctx, ) = Trailblazer::Developer.wtf?( MemoController._normalizer, [{controller: Controller.new("bla")}])

    ctx.inspect.must_equal %{{:controller=>#<struct ConfigTest::Controller params=\"bla\">, :options_for_endpoint=>{:find_process_model=>true, :params=>\"bla\"}, :options_for_domain_ctx=>{}}}
  end

  class EmptyController < ApplicationController
    # for whatever reason, we don't override anything here.
  end

  class MemoController < EmptyController
    def self.options_for_endpoint(ctx, **)
      {
        request: "Request"
      }
    end

    def self.options_for_endpoint(ctx, controller:, **)
      {
        params: controller.params,
      }
    end
  end

  # it do
  #   MemoController.normalize_for(controller: "Controller")
  # end
end
