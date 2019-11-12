module DevboxLauncher
  class CLI < Thor

    WAIT_BOOT_IN_SECONDS = 10.freeze
    DEFAULT_IDENTIFY_FILE_PATH = "~/.ssh/google_compute_engine".freeze
    SSH_CONFIG_PATH = File.expand_path("~/.ssh/config").freeze

    desc "start boxname", "Start a devbox by name"
    def start(name, username=nil)
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
 
      name_or_username = username || name

      set_ssh_config!(hostname, {
        username: name_or_username,
        ip: ip,
       })

      wait_boot(hostname, name_or_username)
    end

    no_commands do
      def wait_boot(hostname, username)
        Net::SSH.start(hostname, username, timeout: WAIT_BOOT_IN_SECONDS) do |ssh|
          puts "[#{ssh.exec!('date').chomp}] Machine booted"
        end
      rescue Net::SSH::ConnectionTimeout, Net::SSH::Disconnect, Errno::ECONNRESET
        puts "Not booted. Waiting #{WAIT_BOOT_IN_SECONDS} seconds before trying again..."
        wait_boot hostname, username
      end

      def set_ssh_config!(hostname, username:, ip:)
        FileUtils.touch(SSH_CONFIG_PATH)
        config = ConfigFile.new
        args = {
          "HostName" => ip,
          "User" => username,
          "IdentityFile" => DEFAULT_IDENTIFY_FILE_PATH,
        }
        args.each do |key, value|
          config.set(hostname, key, value)
        end
        config.save
      end
    end

  end
end