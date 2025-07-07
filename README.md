# MCP Sample Server

MCPサーバーのサンプル。


## セットアップ

1. bundle install
```bash
bundle install
```

## サーバー起動方法

```bash
ruby servers/http_server.rb
```

## 使用方法

### initialize

```bash
curl -i -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "id": 1,
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "test",
        "version": "1.0"
      }
    }
  }'
```

### tools_list

```bash
curl -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 2
  }'
```

#### add_numbers

```bash
curl -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": 3,
    "params": {
      "name": "add_numbers",
      "arguments": {
        "a": 5,
        "b": 3
      }
    }
  }'
```

#### echo

```bash
curl -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": 4,
    "params": {
      "name": "echo",
      "arguments": {
        "message": "Hello, MCP!"
      }
    }
  }'
```

#### get_weather

```bash
curl -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "id": 5,
    "params": {
      "name": "get_weather",
      "arguments": {
        "city": "Tokyo"
      }
    }
  }'
```

### resources_list

```bash
curl -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "resources/list",
    "id": 6
  }'
```

#### resources_read

```bash
curl -X POST http://localhost:9292 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "resources/read",
    "id": 7,
    "params": {
      "uri": "test_resource"
    }
  }'
```

