# frozen_string_literal: true

require "mcp"
require "rack"
require "rackup"
require "json"
require "logger"
require_relative "tools/get_weather"

# Create a simple tool
class ExampleTool < MCP::Tool
  description "A simple example tool that adds two numbers"
  input_schema(
    properties: {
      a: { type: "number" },
      b: { type: "number" },
    },
    required: ["a", "b"],
  )

  class << self
    def call(a:, b:)
      MCP::Tool::Response.new([{
        type: "text",
        text: "The sum of #{a} and #{b} is #{a + b}",
      }])
    end
  end
end

# Create a simple prompt
class ExamplePrompt < MCP::Prompt
  description "A simple example prompt that echoes back its arguments"
  arguments [
    MCP::Prompt::Argument.new(
      name: "message",
      description: "The message to echo back",
      required: true,
    ),
  ]

  class << self
    def template(args, server_context:)
      MCP::Prompt::Result.new(
        messages: [
          MCP::Prompt::Message.new(
            role: "user",
            content: MCP::Content::Text.new(args[:message]),
          ),
        ],
      )
    end
  end
end

# Set up the server
server = MCP::Server.new(
  name: "example_http_server",
  tools: [ExampleTool, WeatherTool],
  prompts: [ExamplePrompt],
  resources: [
    MCP::Resource.new(
      uri: "test_resource",
      name: "Test resource",
      description: "Test resource that echoes back the uri as its content",
      mime_type: "text/plain",
    ),
  ],
)

server.define_tool(
  name: "echo",
  description: "A simple example tool that echoes back its arguments",
  input_schema: { properties: { message: { type: "string" } }, required: ["message"] },
) do |message:|
  MCP::Tool::Response.new(
    [
      {
        type: "text",
        text: "Hello from echo tool! Message: #{message}",
      },
    ],
  )
end

server.resources_read_handler do |params|
  [{
    uri: params[:uri],
    mimeType: "text/plain",
    text: "Hello from HTTP server resource!",
  }]
end

# Create a logger for MCP-specific logging
mcp_logger = Logger.new($stdout)
mcp_logger.formatter = proc do |_severity, _datetime, _progname, msg|
  "[MCP] #{msg}\n"
end

# Simple HTTP handler for MCP JSON-RPC requests
class MCPHTTPHandler
  def initialize(server, logger)
    @server = server
    @logger = logger
    @sessions = {}
  end

  def handle_request(request)
    if request.post?
      body = request.body.read
      request.body.rewind

      begin
        parsed_body = JSON.parse(body)
        @logger.info("Request: #{parsed_body["method"]} (id: #{parsed_body["id"]})")
        @logger.debug("Request body: #{JSON.pretty_generate(parsed_body)}")

        response_data = handle_jsonrpc_request(parsed_body)
        response_json = JSON.generate(response_data)

        @logger.info("Response: #{response_data["result"] ? "success" : "empty"} (id: #{response_data["id"]})")
        @logger.debug("Response body: #{JSON.pretty_generate(response_data)}")

        [200, {"Content-Type" => "application/json"}, [response_json]]
      rescue JSON::ParserError => e
        @logger.warn("Request body (raw): #{body}")
        error_response = {
          jsonrpc: "2.0",
          error: { code: -32700, message: "Parse error: #{e.message}" },
          id: nil
        }
        [400, {"Content-Type" => "application/json"}, [JSON.generate(error_response)]]
      rescue => e
        @logger.error("Request handling error: #{e.message}")
        error_response = {
          jsonrpc: "2.0",
          error: { code: -32603, message: "Internal error: #{e.message}" },
          id: nil
        }
        [500, {"Content-Type" => "application/json"}, [JSON.generate(error_response)]]
      end
    else
      # GET request - return server info
      info = {
        name: @server.name,
        version: @server.version || "1.0.0",
        description: "MCP HTTP Server",
        methods: ["initialize", "tools/list", "tools/call", "resources/list", "resources/read"]
      }
      [200, {"Content-Type" => "application/json"}, [JSON.pretty_generate(info)]]
    end
  end

  private

  def handle_jsonrpc_request(request)
    method = request["method"]
    params = request["params"] || {}
    id = request["id"]

    case method
    when "initialize"
      {
        jsonrpc: "2.0",
        result: {
          protocolVersion: "2024-11-05",
          capabilities: {
            tools: {},
            resources: {}
          },
          serverInfo: {
            name: @server.name,
            version: @server.version || "1.0.0"
          }
        },
        id: id
      }
    when "tools/list"
      tools = []
      # ExampleToolの情報を追加
      tools << {
        name: "add_numbers",
        description: "A simple example tool that adds two numbers",
        inputSchema: {
          type: "object",
          properties: {
            a: { type: "number" },
            b: { type: "number" }
          },
          required: ["a", "b"]
        }
      }
      # echoツールの情報を追加
      tools << {
        name: "echo",
        description: "A simple example tool that echoes back its arguments",
        inputSchema: {
          type: "object",
          properties: {
            message: { type: "string" }
          },
          required: ["message"]
        }
      }
      # 天気ツールの情報を追加
      tools << {
        name: "get_weather",
        description: "指定した都市の現在の天気を取得します",
        inputSchema: {
          type: "object",
          properties: {
            city: { type: "string", description: "都市名（例：Tokyo, Osaka, Kyoto）" }
          },
          required: ["city"]
        }
      }

      {
        jsonrpc: "2.0",
        result: { tools: tools },
        id: id
      }
    when "tools/call"
      tool_name = params["name"]
      arguments = params["arguments"] || {}

      result = case tool_name
      when "add_numbers"
        ExampleTool.call(a: arguments["a"], b: arguments["b"])
      when "get_weather"
        WeatherTool.call(city: arguments["city"])
      when "echo"
        @server.instance_eval do
          @tools["echo"].call(**arguments.transform_keys(&:to_sym))
        end
      else
        raise "Unknown tool: #{tool_name}"
      end

      {
        jsonrpc: "2.0",
        result: { content: result.content },
        id: id
      }
    when "resources/list"
      resources = @server.resources.map do |resource|
        {
          uri: resource.uri,
          name: resource.name,
          description: resource.description,
          mimeType: resource.mime_type
        }
      end

      {
        jsonrpc: "2.0",
        result: { resources: resources },
        id: id
      }
    when "resources/read"
      uri = params["uri"]
      # シンプルなリソースレスポンスを返す
      resource_data = [{
        uri: uri,
        mimeType: "text/plain",
        text: "Hello from HTTP server resource!"
      }]

      {
        jsonrpc: "2.0",
        result: { contents: resource_data },
        id: id
      }
    else
      {
        jsonrpc: "2.0",
        error: { code: -32601, message: "Method not found: #{method}" },
        id: id
      }
    end
  rescue => e
    {
      jsonrpc: "2.0",
      error: { code: -32603, message: "Internal error: #{e.message}" },
      id: id
    }
  end
end

# Create a Rack application with logging
handler = MCPHTTPHandler.new(server, mcp_logger)

app = proc do |env|
  request = Rack::Request.new(env)
  handler.handle_request(request)
end

# Wrap the app with Rack middleware
rack_app = Rack::Builder.new do
  # Use CommonLogger for standard HTTP request logging
  use(Rack::CommonLogger, Logger.new($stdout))

  # Add other useful middleware
  use(Rack::ShowExceptions)

  run(app)
end

# Start the server
puts "Starting MCP HTTP server on http://localhost:9292"
puts "Use POST requests to initialize and send JSON-RPC commands"
puts "Example initialization:"
puts '  curl -i -X POST http://localhost:9292 -H "Content-Type: application/json" -d \'{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\''
puts ""
puts "The server will return a session ID in the Mcp-Session-Id header."
puts "Use this session ID for subsequent requests."
puts ""
puts "Press Ctrl+C to stop the server"

# Run the server
# Use Rackup to run the server
Rackup::Handler.get("puma").run(rack_app, Port: 9292, Host: "localhost")
