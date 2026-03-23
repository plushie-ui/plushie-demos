# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "plushie"
require_relative "../lib/gauge_extension"
require_relative "../lib/temperature_monitor"

require "minitest/autorun"
