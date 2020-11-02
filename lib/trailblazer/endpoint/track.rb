class Trailblazer::Endpoint::Track
  def initialize(adapter)
    @adapter = adapter
  end

  def track(semantic, &block)
    @adapter.define_method("render_#{semantic}".to_sym, &block)

    self
  end
end
