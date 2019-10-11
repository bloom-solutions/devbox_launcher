module DevboxLauncher
  class CLI < Thor

    desc "start boxname", "Start a devbox by name"
    def start(name)
      require "pry"
      start_command = %Q(gcloud compute instances start #{name})
      start_stdout, start_stderr, start_status = Open3.capture3(start_command)

      describe_command = %Q(gcloud compute instances describe #{name})
      describe_stdout, describe_stderr, describe_status =
        Open3.capture3(describe_command)

      description = YAML.load(describe_stdout)

      ip = description["networkInterfaces"].first["accessConfigs"].
        find { |config| config["kind"] == "compute#accessConfig" }["natIP"]

      hostname = "#{name}-devbox"
 
      Ghost::Cli.new.parse(["set", hostname, ip])
    end

  end
end