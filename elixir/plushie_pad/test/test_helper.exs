experiments_dir = Application.get_env(:plushie_pad, :experiments_dir, "tmp/test_experiments")
File.rm_rf!(experiments_dir)
File.mkdir_p!(experiments_dir)

plushie_opts = Plushie.Test.setup!()
ExUnit.start(plushie_opts)
