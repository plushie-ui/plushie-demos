# AGENTS.md

## Ruby Demos

Each child directory is an independent Bundler project. Use the demo's
Gemfile and Rakefile as the source of truth for checks.

## Setup

Use Ruby 3.2 or newer. Native widget demos require Rust and may need
renderer source available through the SDK's build configuration.

## Commands

Run `just preflight` in `ruby/` to verify every Ruby demo.

For one demo:

```sh
bundle install
bundle check
bundle exec rake
bundle exec rake plushie:build
```

Only run the `plushie:build` task for demos with native widgets.
