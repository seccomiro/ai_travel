module AITools
  class BaseTool
    # This method should be implemented by subclasses to return the
    # JSON schema for the tool, which is used by the OpenAI API.
    def self.definition
      raise NotImplementedError, "#{name} must implement the .definition class method."
    end
  end
end 