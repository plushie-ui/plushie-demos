# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "plushie"
require "plushie/test"
require_relative "../lib/sparkline_extension"
require_relative "../lib/dashboard"

require "minitest/autorun"
