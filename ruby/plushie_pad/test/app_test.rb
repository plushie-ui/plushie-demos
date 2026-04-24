# frozen_string_literal: true

require_relative "test_helper"

class AppTest < Minitest::Test
  Event = Plushie::Event

  def setup
    @app = PlushiePad::App.new
    @model = @app.init(nil)
  end

  def test_init_loads_starter_experiment
    assert_equal "hello.rb", @model.active_file
    assert_includes @model.source, "Experiment.view"
  end

  def test_view_builds_window_tree
    tree = @app.view(@model)
    assert_equal "window", tree.type
    assert_equal "main", tree.id
  end

  def test_editor_input_sets_dirty_and_pushes_undo
    updated = @app.update(@model, Event::Widget.new(
      type: :input,
      id: "editor",
      value: "# new source"
    ))
    assert updated.dirty
    assert_equal "# new source", updated.source
    refute_equal @model.undo_stack, updated.undo_stack
  end

  def test_ctrl_s_renders_and_clears_dirty
    dirty = @app.update(@model, Event::Widget.new(
      type: :input,
      id: "editor",
      value: @model.source
    ))
    saved = @app.update(dirty, Event::Key.new(
      type: :press,
      key: "s",
      modifiers: {command: true}
    ))
    refute saved.dirty
    refute_nil saved.preview
  end

  def test_escape_clears_error
    with_error = @model.with(error: "boom")
    cleared = @app.update(with_error, Event::Key.new(type: :press, key: "Escape"))
    assert_nil cleared.error
  end

  def test_subscribe_auto_save_only_when_dirty
    assert_equal [:on_key_press], @app.subscribe(@model).map(&:type)
    dirty_auto = @model.with(auto_save: true, dirty: true)
    types = @app.subscribe(dirty_auto).map(&:type)
    assert_includes types, :every
  end
end

class CompileTest < Minitest::Test
  def test_valid_source_returns_ok
    source = <<~RUBY
      module Experiment
        def self.view
          Plushie::Widget::Text.new("x", "y").build
        end
      end
    RUBY
    status, tree = PlushiePad::Compile.compile_and_render(source)
    assert_equal :ok, status
    assert_equal "text", tree.type
  end

  def test_missing_view_returns_error
    status, msg = PlushiePad::Compile.compile_and_render("module Experiment; end")
    assert_equal :error, status
    assert_match(/must define Experiment\.view/, msg)
  end

  def test_runtime_exception_returns_error
    source = <<~RUBY
      module Experiment
        def self.view
          raise "boom"
        end
      end
    RUBY
    status, msg = PlushiePad::Compile.compile_and_render(source)
    assert_equal :error, status
    assert_match(/boom/, msg)
  end
end
