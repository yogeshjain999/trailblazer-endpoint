module Trailblazer
  module Endpoint
    class Matcher
      def self.call( (matcher_cfg, options), *args, &block)
        # find the action.
        pattern, action = matcher_cfg.find do |pattern, action|
          pattern.( *args, &block ) # call the pattern and simply pass on the args.
        end

        raise "not implemented" unless action

        action.(*args, options, &block)
      end


      DEFAULT_MATCHERS = {
        created: {
          rule: ->(result) { result.success? && result["model.action"] == :new },
          resolve: lambda do |result, representer|
            {
              "data": representer.new(result["model"]),
              "status": :created
            }
          end
        },
        success: {
          rule: ->(result) { result.success? },
          resolve: lambda do |result, representer|
            {
              "data": representer.new(result["model"]),
              "status": :ok
            }
          end
        },
        unauthenticated: {
          rule: lambda do |result|
            result.failure? && result["result.policy.default"]&.failure?
          end,
          resolve: lambda do |_result, _representer|
            {
              "data": {},
              "status": :unauthorized
            }
          end
        },
        not_found: {
          rule: lambda do |result|
            result.failure? && result["result.model"]&.failure?
          end,
          resolve: lambda do |_result, _representer|
            {
              "data": {},
              "status": :not_found
            }
          end
        },
        contract_failure: {
          rule: lambda do |result|
            result.failure? && result["result.contract.default"]&.failure?
          end,
          resolve: lambda do |result, _representer|
            {
              "data": {
                messages: result["result.contract.default"]&.errors&.messages
              },
              "status": :unprocessable_entity
            }
          end
        },
        fallback: {
          rule: ->(_result) { true },
          resolve: lambda do |_result, _representer|
            {
              "data": {
                messages: ["Unexpected operation result"]
              },
              "status": :unprocessable_entity
            }
          end
        }
      }

      # options expects a TRB Operation result
      # it might have a representer, else will assume the default name
      def self.__call(operation_result, representer_class = nil, overrides = {})
        representer = operation_result["representer.serializer.class"] || representer_class
        endpoint_opts = { result: operation_result, representer: representer }
        new.(endpoint_opts, overrides)
      end

      def __call(options, overrides)
        overrides.each do |rule_key, rule_description|
          rule = rule_description[:rule] || DEFAULT_MATCHERS[rule_key][:rule]
          resolve = rule_description[:resolve] || DEFAULT_MATCHERS[rule_key][:resolve]
          if rule.nil? || resolve.nil?
            puts "Matcher is not properly set. #{rule_key} will be ignored"
            next
          end

          if rule.(options[:result])
            return resolve.(options[:result], options[:representer])
          end
        end
        matching_rules(overrides).each do |_rule_key, rule_description|
          if rule_description[:rule].(options[:result])
            return rule_description[:resolve].(options[:result], options[:representer])
          end
        end
      end

      def matching_rules(overrides)
        DEFAULT_MATCHERS.reject { |k, _v| overrides.keys.include? k }
      end
    end # Matcher
  end
end
