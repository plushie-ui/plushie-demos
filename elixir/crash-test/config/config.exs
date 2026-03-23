import Config

config :plushie,
  artifacts: [:bin],
  extensions: [CrashTest.CrashExtension],
  build_name: "crash-test-plushie"
