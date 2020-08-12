# DISCUSS: the generic inheritance/Options logic might be extracted to trailblazer-config or something.
#          it is completely independent and could be helpful for many other configurations.
module Trailblazer
  class Endpoint
    module Options
      module DSL
        def directive(directive_name, *callables, inherit: superclass)
          options = {}

          if inherit
            options[:base_class] = instance_variable_get(:@normalizers)[directive_name] || Trailblazer::Activity::Path # FIXME
          end

          @normalizers[directive_name] = Trailblazer::Endpoint::Normalizer.Options(directive_name, *callables, **options) # DISCUSS: allow multiple calls?
        end

        # Called in {Endpoint::Controller}.
        def self.extended(extended) # TODO: let's hope this is only called once per hierachy :)
          extended.instance_variable_set(:@normalizers, {})
        end

        module Inherit
          def inherited(subclass)
            super

            subclass.instance_variable_set(:@normalizers, @normalizers.dup)
          end
        end
      end

      def options_for(directive_name, runtime_options)
        normalizer = @normalizers[directive_name]

        ctx = Trailblazer::Context::IndifferentAccess.build(runtime_options, {}, [{}, {}], {}) # FIXME: easier {::build}, please!

        signal, (ctx, ) = Trailblazer::Developer.wtf?(normalizer, [ctx])

        _, options = ctx.decompose
        options
      end
    end

    module Normalizer
      def self.Options(directive_name, *callables, base_class: Trailblazer::Activity::Path)
        normalizer = Class.new(base_class) do
        end

        Normalizer.add(normalizer, directive_name, callables)
      end

      def self.DefaultToEmptyHash(config_name)
        -> (ctx, **) { ctx[config_name] ||= {} }
      end

      def self.add_normalizer!(target, normalizer, config)
        normalizer = Normalizer.add(normalizer, target, config) # add configure steps for {subclass} to the _new_ normalizer.
        target.instance_variable_set(:@normalizer, normalizer)
        target.instance_variable_set(:@config, config)
      end

      class State < Module
        def initialize(normalizer, config)
          @normalizer = normalizer
          @config = config
        end

        # called once when extended in {ApplicationController}.
        def extended(extended)
          super

          extended.extend(Inherited)
          Normalizer.add_normalizer!(extended, @normalizer, @config)
        end

      end
      module Inherited
        def inherited(subclass)
          super

          Normalizer.add_normalizer!(subclass, @normalizer, @config)
        end
      end

      def self.add(normalizer, directive_name, options)
        Class.new(normalizer) do
          options.collect do |callable|
            step task: Normalizer.CallDirective(callable, directive_name), id: "#{directive_name}=>#{callable}"
          end
        end
      end

      def self.CallDirective(callable, option_name)
        ->((ctx, flow_options), *) {
          config = callable.(ctx, **ctx) # e.g. ApplicationController.options_for_endpoint

          # ctx[option_name] = ctx[option_name].merge(config)
          config.each do |k, v|
            ctx[k] = v
          end

          return Trailblazer::Activity::Right, [ctx, flow_options]
        }
      end
    end # Normalizer
  end
end
