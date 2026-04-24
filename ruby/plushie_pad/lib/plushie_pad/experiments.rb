# frozen_string_literal: true

require "fileutils"

module PlushiePad
  # File-backed experiment store. Experiments live as .rb files under
  # the experiments/ directory alongside the pad's own source.
  #
  # Files are read, written, listed, and deleted as plain strings. No
  # sandboxing or validation: the pad trusts the user with the
  # experiment directory.
  module Experiments
    # Directory holding experiment source files.
    DIR = File.expand_path("../../experiments", __dir__)

    # List every experiment filename (sorted). Returns e.g. ["hello.rb"].
    def self.list
      return [] unless Dir.exist?(DIR)
      Dir.children(DIR).select { |f| f.end_with?(".rb") }.sort
    end

    # Load an experiment's source. Returns "" if the file doesn't exist.
    def self.load(name)
      path = File.join(DIR, name)
      File.exist?(path) ? File.read(path) : ""
    end

    # Write an experiment's source to disk atomically.
    def self.save(name, source)
      FileUtils.mkdir_p(DIR)
      path = File.join(DIR, name)
      tmp = "#{path}.tmp"
      File.write(tmp, source)
      File.rename(tmp, path)
      nil
    end

    # Remove an experiment file if it exists.
    def self.delete(name)
      path = File.join(DIR, name)
      File.unlink(path) if File.exist?(path)
      nil
    end

    # Return a starter source string. Uses the typed builder API so
    # experiments don't depend on the block-DSL context stack.
    def self.starter_source(label)
      <<~RUBY
        # Experiment: #{label}
        # Define Experiment.view returning a Plushie node.
        module Experiment
          def self.view
            Plushie::Widget::Column.new("root", padding: 16, spacing: 8)
              .push(Plushie::Widget::Text.new("greeting", "Hello from #{label}!", size: 24))
              .push(Plushie::Widget::Text.new("hint", "Edit me and press Save."))
              .build
          end
        end
      RUBY
    end
  end
end
