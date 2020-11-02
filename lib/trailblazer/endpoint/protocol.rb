require "trailblazer/activity/dsl/linear"

module Trailblazer
  class Endpoint
    # The {Protocol} implements auth*, and calls the domain OP/WF.
    # You still have to implement handlers (like {#authorize} and {#handle_not_authorized}) yourself. This might change soon.
    #
    # Protocol must provide all ends for the Adapter (401,403 and 404 in particular), even if the ran op/workflow doesn't have it.
    #   Still thinking about how to do that best.

    # Termini and their "pendants" in HTTP, which is unrelated to protocol!! Protocol is application-focused and doesn't know about HTTP.
    #   failure: 411
    #   success: 200
    #   not_found: 404
    #   not_authenticated: 401
    #   not_authorized: 403
    class Protocol < Trailblazer::Activity::Railway
      NotAuthenticated  = Class.new(Trailblazer::Activity::Signal)
      NotFound          = Class.new(Trailblazer::Activity::Signal)
      NotAuthorized     = Class.new(Trailblazer::Activity::Signal)

      step :authenticate, Output(NotAuthenticated, :not_authenticated) => End(:not_authenticated)

      # Here, we test a domain OP with ADDITIONAL explicit ends that get wired to the Adapter (vaidation_error => failure).
      # We still need to test the other way round: wiring a "normal" failure to, say, not_found, by inspecting the ctx.
      step nil, id: :domain_activity

      def self.mapped_stop_events_to_output_tracks
        graph = Trailblazer::Activity::Introspect::Graph(self)

        outputs = graph.stop_events.collect do |stop_event|
          semantic = stop_event.to_h[:semantic]
          [Output(semantic), Track(semantic)]
        end

        outputs.to_h
      end

      module Domain
        # taskWrap step that saves the return signal of the {domain_activity}.
        # The taskWrap step is usually inserted after {task_wrap.output}.
        def self.terminus_handler(wrap_ctx, original_args)

        #      Unrecognized Signal `"bla"` returned from EndpointTest::LegacyCreate. Registered signals are,
        # - #<Trailblazer::Activity::End semantic=:failure>
        # - #<Trailblazer::Activity::End semantic=:success>
        # - #<Trailblazer::Activity::End semantic=:fromail_fast>

        # {:return_args} is the original "endpoint ctx" that was returned from the {:output} filter.
          wrap_ctx[:return_args][0][:domain_activity_return_signal] = wrap_ctx[:return_signal]

          return wrap_ctx, original_args
        end

        def self.extension_for_terminus_handler
          # this is called after {:output}.
          [[Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_after), "task_wrap.call_task", ["endpoint.end_signal", method(:terminus_handler)]]]
        end

        def self.outputs_for(domain_activity)
          graph = Trailblazer::Activity::Introspect::Graph(domain_activity)

          outputs = {
            Protocol.Output(:failure) => Protocol.End(:invalid_data),
          }

          if graph.stop_events.find{ |se| se.to_h[:semantic] == :not_authorized }
            outputs.merge!(Protocol.Output(:not_authorized) => Protocol.End(:not_authorized))
          end

          if graph.stop_events.find{ |se| se.to_h[:semantic] == :not_found }
            outputs.merge!(Protocol.Output(:not_found) => Protocol.End(:not_found))
          end

          outputs
        end
      end

    end
  end
end
