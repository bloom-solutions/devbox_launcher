module DevboxLauncher
  class Box

    WAIT_BOOT_RESCUED_EXCEPTIONS = [
      Net::SSH::ConnectionTimeout,
      Net::SSH::Disconnect,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
    ]
    WAIT_BOOT_IN_SECONDS = 10.freeze
    MAX_BOOT_RETRIES = 10
    DEFAULT_IDENTIFY_FILE_PATH = "~/.ssh/google_compute_engine".freeze
    SSH_CONFIG_PATH = File.expand_path("~/.ssh/config").freeze
    CONFIG_PATH = File.expand_path("~/.devbox_launcher.yml").freeze
    CONFIG = YAML.load_file(CONFIG_PATH).freeze

    attr_reader :account, :options

    def initialize(account, options)
      @account = account
      @options = options
    end

    def start
      start_stdout, start_stderr, start_status =
        Open3.capture3(start_cmd)

      set_ssh_config!

      wait_boot

      reset_mutagen_session

      connect_mosh
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

    def connect_mosh
      return if options[:mosh].nil?

      mosh_cmd = %Q(mosh #{hostname})
      system(mosh_cmd)
    end

    def wait_boot(tries: 1)
      Net::SSH.start(hostname, username, timeout: WAIT_BOOT_IN_SECONDS) do |ssh|
        puts "[#{ssh.exec!('date').chomp}] Machine booted"
      end
    rescue *WAIT_BOOT_RESCUED_EXCEPTIONS
      puts "Not booted. Waiting #{WAIT_BOOT_IN_SECONDS} seconds before trying again..."

      sleep WAIT_BOOT_IN_SECONDS

      if !description(reload: true).running?
        puts "Detected that the machine is not running " \
          "(status is #{description.status}). Booting it..."
        start
      end

      fail if tries >= MAX_BOOT_RETRIES

      wait_boot tries: tries+1
    end

    def description(reload: false)
      return @description if !reload && @description

      puts "Fetching box's description..."

      describe_stdout, describe_stderr, describe_status =
        Open3.capture3(describe_cmd)

      if !describe_status.success?
        msg = "Problem fetching the description of #{name}. "
        msg += "Please ensure you can call `#{describe_cmd}`.\n"
        msg += "Error:\n"
        msg += describe_stderr
        fail msg
      end

      @description = Description.new(describe_stdout)
    end

    def describe_cmd
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
        "describe",
        name,
        args
      ].join(" ")
    end

    def set_ssh_config!
      FileUtils.touch(SSH_CONFIG_PATH)
      config = ConfigFile.new
      args = {
        "HostName" => description.ip,
        "User" => username,
        "IdentityFile" => DEFAULT_IDENTIFY_FILE_PATH,
      }
      args.each do |key, value|
        config.set(hostname, key, value)
      end
      config.save
    end

    def reset_mutagen_session
      return if !mutagen_config.configured?

      terminate_mutagen_session
      create_mutagen_session
      watch_alpha if OS.linux?
    end

    def terminate_mutagen_session
      puts "Terminating mutagen session..."
      terminate_mutagen_cmd =
        %Q(mutagen terminate --label-selector=#{label})
      terminate_mutagen_stdout,
        terminate_mutagen_stderr,
        terminate_mutagen_status =
        Open3.capture3(terminate_mutagen_cmd)

      if not terminate_mutagen_status.success?
        # mutagen prints to stdout and stderr
        msg = "Failed to terminate mutagen sessions: " \
          "#{terminate_mutagen_stdout} -" \
          "#{terminate_mutagen_stderr}"
        fail msg
      end
    end

    def label
      "#{username}=#{name}",
    end

    def create_mutagen_session
      puts "Create mutagen session syncing local " \
        "#{mutagen_config.alpha_dir} with " \
        "#{hostname} #{mutagen_config.beta_dir}"

      create_mutagen_cmd = [
        "mutagen sync create",
        mutagen_config.alpha_dir,
        "#{hostname}:#{mutagen_config.beta_dir}",
        "--label=#{label}",
      ]
      create_mutagen_cmd << "--watch-mode-alpha=no-watch" if OS.linux?

      create_mutagen_stdout,
        create_mutagen_stderr,
        create_mutagen_status =
        Open3.capture3(create_mutagen_cmd.join(" "))

      if not create_mutagen_status.success?
        # mutagen prints to stdout and stderr
        msg = "Failed to create mutagen sessions: " \
          "#{create_mutagen_stdout} -" \
          "#{create_mutagen_stderr}"
        fail msg
      end
    end

    def watch_alpha
      watchman = Watchman.new(dir: mutagen_config.alpha_dir)
      watchman.trigger("mutagen sync flush --label-selector=#{label}")
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

    def mutagen_config
      @mutagen_config ||= Mutagen.new(config[:mutagen])
    end

  end
end
