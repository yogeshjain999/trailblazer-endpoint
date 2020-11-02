module Trailblazer
  class Endpoint

    # The idea is to use the CreatePrototypeProtocol's outputs as some kind of protocol, outcomes that need special handling
    # can be wired here, or merged into one (e.g. 401 and failure is failure).
    # I am writing this class in the deep forests of the Algarve, hiding from the GNR.
    # class Adapter < Trailblazer::Activity::FastTrack # TODO: naming. it's after the "application logic", more like Controller
 # Currently reusing End.fail_fast as a "something went wrong, but it wasn't a real application error!"


    module Adapter
      class Web < Trailblazer::Activity::Railway
        step nil, id: :protocol

        step :render_success
        step :render_not_authenticated, magnetic_to: :not_authenticated
        step :render_not_authorized, magnetic_to: :not_authorized
        step :render_unprocessable_entity, magnetic_to: :invalid_data
        step :render_not_found, magnetic_to: :not_found
      end # Web

      class API < Web
      end # API
    end
  end
end
