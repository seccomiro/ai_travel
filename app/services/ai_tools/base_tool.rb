module AITools
  class BaseTool
    def initialize(trip)
      @trip = trip
    end

    # This method should be implemented by subclasses to return the
    # JSON schema for the tool, which is used by the OpenAI API.
    def definition
      raise NotImplementedError, "#{self.class.name} must implement the #definition instance method."
    end
  end
end
