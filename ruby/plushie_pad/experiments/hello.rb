# Experiment: hello
# Define Experiment.view returning a Plushie node.
module Experiment
  def self.view
    Plushie::Widget::Column.new("root", padding: 16, spacing: 8)
      .push(Plushie::Widget::Text.new("greeting", "Hello from hello!", size: 24))
      .push(Plushie::Widget::Text.new("hint", "Edit me and press Save."))
      .build
  end
end
