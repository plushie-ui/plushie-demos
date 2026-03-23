# frozen_string_literal: true

require "socket"
require "json"
require "securerandom"
require "websocket/driver"
require "plushie"
require_relative "shared"

class Collab
  # HTTP + WebSocket server for shared-state collaboration.
  #
  # Serves static files from the public/ directory and handles
  # WebSocket upgrades on /ws. Each WebSocket client gets its own
  # thread and registers with the Shared state broker.
  class Server
    MIME_TYPES = {
      ".html" => "text/html",
      ".js" => "application/javascript",
      ".mjs" => "application/javascript",
      ".wasm" => "application/wasm",
      ".css" => "text/css",
      ".json" => "application/json",
      ".png" => "image/png",
      ".svg" => "image/svg+xml"
    }.freeze

    def initialize(host: "127.0.0.1", port: 8080, public_dir: nil)
      @host = host
      @port = port
      @public_dir = public_dir || File.join(__dir__, "..", "..", "public")
      @wasm_dir = File.join(__dir__, "..", "..", "_build", "plushie", "wasm")
      @shared = Shared.new
      @app = Collab.new
    end

    def start
      server = TCPServer.new(@host, @port)
      puts "Collab server listening on http://#{@host}:#{@port}"
      puts "Open http://#{@host}:#{@port}/websocket.html in a browser"
      puts "Press Ctrl-C to stop"

      loop do
        client = server.accept
        Thread.new(client) { |sock| handle_connection(sock) }
      rescue => e
        warn "Accept error: #{e.message}"
      end
    ensure
      server&.close
    end

    private

    def handle_connection(socket)
      request_line = socket.gets
      return unless request_line

      headers = {}
      while (line = socket.gets) && line != "\r\n"
        key, value = line.split(": ", 2)
        headers[key.downcase.strip] = value&.strip
      end

      method, path, = request_line.split(" ")

      if method == "GET" && path == "/ws" && headers["upgrade"]&.downcase == "websocket"
        raw = "#{request_line}#{headers.map { |k, v| "#{k}: #{v}\r\n" }.join}\r\n"
        handle_websocket(socket, raw)
      elsif method == "GET"
        serve_static(socket, path)
      else
        send_response(socket, 405, "text/plain", "Method Not Allowed")
      end
    rescue => e
      warn "Connection error: #{e.message}"
    ensure
      socket&.close
    end

    def handle_websocket(socket, raw_request)
      wrapper = SocketWrapper.new(socket)
      driver = WebSocket::Driver.server(wrapper)

      client_id = "ws-#{SecureRandom.hex(4)}"
      dark_mode = false

      driver.on :open do
        model = @shared.connect(client_id) do |m|
          client_model = m.with(dark_mode: dark_mode)
          send_snapshot(driver, client_model)
        end
        send_snapshot(driver, model)
      end

      driver.on :message do |ws_event|
        msg = JSON.parse(ws_event.data)

        if msg["type"] == "event"
          event = Plushie::Protocol::Decode.dispatch_message(msg)
          if event.is_a?(Plushie::Event::Widget) && event.id == "theme" && event.type == :toggle
            dark_mode = event.data["value"]
          elsif event
            @shared.event(client_id, event)
          end
        end
      rescue => err
        warn "WS message error: #{err.message}"
      end

      driver.on :close do
        @shared.disconnect(client_id)
      end

      driver.parse(raw_request)

      while (data = socket.readpartial(4096))
        driver.parse(data)
      end
    rescue IOError
      @shared.disconnect(client_id)
    end

    def send_snapshot(driver, model)
      tree = Plushie::Tree.normalize(@app.view(model))
      node = tree.is_a?(Array) ? tree.first : tree
      wire = Plushie::Tree.node_to_wire(node)
      json = JSON.generate({type: "snapshot", session: "", tree: wire})
      driver.text(json)
    rescue => e
      warn "Snapshot error: #{e.message}"
    end

    def serve_static(socket, path)
      path = "/index.html" if path == "/"
      safe_path = File.expand_path(File.join(@public_dir, path))

      # Check public/ first, then _build/plushie-renderer/wasm/ for WASM files
      unless safe_path.start_with?(File.expand_path(@public_dir))
        send_response(socket, 403, "text/plain", "Forbidden")
        return
      end

      file_path = if File.exist?(safe_path)
        safe_path
      elsif File.exist?(File.join(@wasm_dir, File.basename(path)))
        File.join(@wasm_dir, File.basename(path))
      end

      unless file_path && File.file?(file_path)
        send_response(socket, 404, "text/plain", "Not Found")
        return
      end

      ext = File.extname(file_path)
      content_type = MIME_TYPES[ext] || "application/octet-stream"
      body = File.binread(file_path)

      send_response(socket, 200, content_type, body)
    end

    def send_response(socket, status, content_type, body)
      status_text = {200 => "OK", 403 => "Forbidden", 404 => "Not Found", 405 => "Method Not Allowed"}
      socket.write(
        "HTTP/1.1 #{status} #{status_text[status]}\r\n" \
        "Content-Type: #{content_type}\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n" \
        "\r\n"
      )
      socket.write(body)
    end
  end

  # Minimal wrapper for websocket-driver.
  # @api private
  class SocketWrapper
    def initialize(socket)
      @socket = socket
    end

    def url = ""

    def write(data)
      @socket.write(data)
    rescue IOError, Errno::EPIPE
      # Client disconnected
    end
  end
end
