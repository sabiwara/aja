import Config

config_file = "#{Mix.env()}.exs"

if config_file |> Path.expand(__DIR__) |> File.exists?() do
  import_config config_file
end
