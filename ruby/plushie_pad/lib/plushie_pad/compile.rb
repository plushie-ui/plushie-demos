# frozen_string_literal: true

module PlushiePad
  # Compile a user-typed Ruby experiment at runtime.
  #
  # An experiment is a Ruby module (or class) that exposes a zero-arity
  # +view+ method returning a Plushie node tree. The source is
  # evaluated inside an anonymous Module to isolate it from the pad's
  # own namespace; the module's +view+ is then invoked.
  module Compile
    # Evaluate +source+ and return [:ok, tree] or [:error, message].
    #
    # The source must define a constant or set up such that calling
    # +view+ on a freshly-evaluated module returns a Plushie node.
    # Callers embed a wrapper like:
    #
    #   module Experiment
    #     def self.view
    #       # user code
    #     end
    #   end
    #
    # The convention: experiments define +Experiment.view+. Anything
    # else is user freedom.
    def self.compile_and_render(source)
      mod = Module.new
      mod.module_eval(source)
      experiment = mod.const_defined?(:Experiment) ? mod.const_get(:Experiment) : mod
      unless experiment.respond_to?(:view)
        return [:error, "experiment must define Experiment.view"]
      end
      tree = experiment.view
      [:ok, tree]
    rescue ScriptError, StandardError => e
      [:error, "#{e.class}: #{e.message}"]
    end
  end
end
