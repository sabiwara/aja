import Config

run_time = System.get_env("PROP_TEST_RUNTIME", "200") |> String.to_integer()

config :stream_data,
  max_runs: nil,
  max_run_time: run_time
