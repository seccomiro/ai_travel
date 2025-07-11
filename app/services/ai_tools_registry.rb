# This service is responsible for discovering and loading all available AI tools.
# It dynamically loads all tool classes from the app/services/ai_tools directory.
class AIToolsRegistry
  def initialize(trip)
    @trip = trip
    # Ensure all tool files are loaded.
    self.class.tool_files.each { |file| require_dependency file }
  end

  # Returns the JSON schema definitions for all available tools.
  def definitions
    # Return the definitions from all loaded tool classes.
    AITools::BaseTool.subclasses.map do |tool_class|
      tool_class.new(@trip).definition
    end.compact
  end

  # Returns a list of all tool files.
  def self.tool_files
    Dir[Rails.root.join('app', 'services', 'ai_tools', '**', '*_tool.rb')]
  end
end
