# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "plushie"
require "plushie/test"
require_relative "../lib/sparkline_extension"
require_relative "../lib/dashboard"

# The sparkline extension's custom binary doesn't implement new_instance(),
# so it can't support multiplexed sessions. Override the pool to use
# max_sessions: 1.
Plushie::Test.instance_variable_set(:@pool, begin
  pool = Plushie::Test::SessionPool.new(
    mode: Plushie::Test.backend,
    format: :msgpack,
    max_sessions: 1,
    binary: Plushie::Binary.path!
  )
  pool.start
  at_exit { pool.stop }
  pool
end)

require "minitest/autorun"
