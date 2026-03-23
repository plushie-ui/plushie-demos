# frozen_string_literal: true

require_relative "../collab"

class Collab
  # Thread-safe shared state broker for collaborative modes.
  #
  # Holds the authoritative model and a set of connected clients.
  # When any client sends an event, the broker runs update, preserves
  # the server-managed status field, and broadcasts the new model to
  # all connected clients.
  class Shared
    def initialize
      @mutex = Mutex.new
      @app = Collab.new
      @model = @app.init({})
      @clients = {} # id => callback proc
    end

    # Register a client. Returns the current model.
    # The callback is called with the new model on every change.
    def connect(id, &on_model_changed)
      model = nil
      existing = nil
      @mutex.synchronize do
        @clients[id] = on_model_changed
        update_status
        model = @model
        existing = @clients.except(id).values.dup
      end
      # Broadcast updated status to existing clients (outside mutex)
      existing.each do |cb|
        cb.call(model)
      rescue
        nil
      end
      model
    end

    # Unregister a client.
    def disconnect(id)
      model = nil
      callbacks = nil
      @mutex.synchronize do
        @clients.delete(id)
        update_status
        model = @model
        callbacks = @clients.values.dup
      end
      callbacks.each do |cb|
        cb.call(model)
      rescue
        nil
      end
    end

    # Process an event from a client.
    def event(id, event)
      model = nil
      callbacks = nil
      @mutex.synchronize do
        @model = @app.update(@model, event)
        update_status
        model = @model
        callbacks = @clients.values.dup
      end
      callbacks.each do |cb|
        cb.call(model)
      rescue
        nil
      end
    end

    private

    def update_status
      n = @clients.size
      @model = @model.with(status: "#{n} connected")
    end
  end
end
