module DevboxLauncher
  class CLI < Thor

    WAIT_BOOT_IN_SECONDS = 10.freeze

    desc "start boxname", "Start a devbox by name"
    def start(name)
      require "pry"
      start_command = %Q(gcloud compute instances start #{name})
      start_stdout, start_stderr, start_status = Open3.capture3(start_command)

      puts "Fetching IP..."
      describe_command = %Q(gcloud compute instances describe #{name})
      describe_stdout, describe_stderr, describe_status =
        Open3.capture3(describe_command)

      description = YAML.load(describe_stdout)

      ip = description["networkInterfaces"].first["accessConfigs"].
        find { |config| config["kind"] == "compute#accessConfig" }["natIP"]

      hostname = "#{name}-devbox"
 
      Ghost::Cli.new.parse(["set", hostname, ip])

      wait_boot(hostname, name)
    end

    no_commands do
      def wait_boot(hostname, username)
        Net::SSH.start(hostname, username, timeout: WAIT_BOOT_IN_SECONDS) do |ssh|
          puts "Waiting for machine to boot..."
          puts ssh.exec!('date')
        end
      rescue Net::SSH::ConnectionTimeout
        puts "Not booted..."
        wait_boot hostname, username
      end
    end

  end
end