module DevboxLauncher
  class Box

    WAIT_BOOT_RESCUED_EXCEPTIONS = [
      Net::SSH::ConnectionTimeout,
      Net::SSH::Disconnect,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      Errno::ECONNREFUSED,
    ]
    WAIT_BOOT_IN_SECONDS = 10.freeze
    DEFAULT_IDENTIFY_FILE_PATH = "~/.ssh/google_compute_engine".freeze
    SSH_CONFIG_PATH = File.expand_path("~/.ssh/config").freeze
    CONFIG_PATH = File.expand_path("~/.devbox_launcher.yml").freeze
    CONFIG = YAML.load_file(CONFIG_PATH).freeze

    attr_reader :account

    def initialize(account)
      @account = account
    end

    def start
      start_stdout, start_stderr, start_status =
        run_command(start_cmd)

      set_ssh_config!(hostname, {
        username: username,
        ip: description.ip,
      })

      wait_boot

      reset_mutagen_session(
        mutagen_config: config[:mutagen],
        hostname: hostname,
      )
    end

    def start_cmd
      args = {
        project: config[:project],
        account: account,
      }.map do |(key, val)|
        ["--#{key}", val].join("=")
      end.join(" ")

      [
        "gcloud",
        "compute",
        "instances",
        "start",
        name,
        args
      ].join(" ")
    end

    def wait_boot(tries: 1)
      Net::SSH.start(hostname, username, timeout: WAIT_BOOT_IN_SECONDS) do |ssh|
        puts "[#{ssh.exec!('date').chomp}] Machine booted"
      end
    rescue *WAIT_BOOT_RESCUED_EXCEPTIONS
      puts "Not booted. Waiting #{WAIT_BOOT_IN_SECONDS} seconds before trying again..."

      sleep WAIT_BOOT_IN_SECONDS

      description = describe(name)
      if !description.running?
        puts "Detected that the machine is not running " \
          "(status is #{description.status}). Booting it..."
        start_box name, username
      end

      wait_boot name, username, tries: tries+1
    end

    def description(reload: false)
      return @description if !reload && @description

      puts "Fetching box's description..."

      describe_command = %Q(gcloud compute instances describe #{name})
      describe_stdout, describe_stderr, describe_status =
        run_command(describe_command)

      if !describe_status.success?
        msg = "Problem fetching the description of #{name}. "
        msg += "Please ensure you can call `#{describe_command}`.\n"
        msg += "Error:\n"
        msg += describe_stderr
        fail msg
      end

      @description = Description.new(describe_stdout)
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

    def reset_mutagen_session
      mutagen_config = config[:mutagen]
      return if mutagen_config.nil?

      alpha_dir = mutagen_config[:alpha]
      beta_dir = mutagen_config[:beta]

      return if alpha_dir.nil? || beta_dir.nil?

      terminate_mutagen_session

      create_mutagen_session(
        alpha_dir: alpha_dir,
        beta_dir: beta_dir,
        hostname: hostname,
        username: username,
      )

      if OS.linux?
        watch_alpha(alpha_dir: alpha_dir, hostname: hostname)
      end
    end

    def terminate_mutagen_session(username)
      puts "Terminating mutagen session..."
      terminate_mutagen_command =
        %Q(mutagen terminate --label-selector=#{username})
      terminate_mutagen_stdout,
        terminate_mutagen_stderr,
        terminate_mutagen_status =
        run_command(terminate_mutagen_command)

      if not terminate_mutagen_status.success?
        # mutagen prints to stdout and stderr
        msg = "Failed to terminate mutagen sessions: " \
          "#{terminate_mutagen_stdout} -" \
          "#{terminate_mutagen_stderr}"
        fail msg
      end
    end

    def create_mutagen_session(alpha_dir:, beta_dir:, hostname:, username:)
      puts "Create mutagen session syncing local #{alpha_dir} " \
        "with #{hostname} #{beta_dir}"

      create_mutagen_command = [
        "mutagen sync create",
        alpha_dir,
        "#{hostname}:#{beta_dir}",
        "--label=#{username}",
      ]
      create_mutagen_command << "--watch-mode-alpha=no-watch" if OS.linux?

      create_mutagen_stdout,
        create_mutagen_stderr,
        create_mutagen_status =
        run_command(create_mutagen_command.join(" "))

      if not create_mutagen_status.success?
        # mutagen prints to stdout and stderr
        msg = "Failed to create mutagen sessions: " \
          "#{create_mutagen_stdout} -" \
          "#{create_mutagen_stderr}"
        fail msg
      end
    end

    def watch_alpha(alpha_dir:, hostname:)
      watchman = Watchman.new(dir: alpha_dir)
      watchman.trigger("mutagen sync flush --label-selector=#{hostname}")
    end

    def name
      @name ||= config[:box]
    end

    def hostname
      [name, username, "devbox"].join("-")
    end

    def username
      @username ||= account.gsub(/\W/, "_")
    end

    def config
      return @config if @config

      if not CONFIG.has_key?(account)
        fail "No config in #{CONFIG_PATH} found for #{account}"
      end

      @config = CONFIG[account].with_indifferent_access
    end

    def run_command(command, tries: 0)
      Open3.capture3(command)
    rescue *WAIT_BOOT_RESCUED_EXCEPTIONS
      sleep WAIT_BOOT_IN_SECONDS
      run_command(command, tries+1)
    end

  end
end
