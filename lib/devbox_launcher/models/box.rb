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
    MAX_BOOT_RETRIES = 20
    SSH_CONFIG_PATH = File.expand_path("~/.ssh/config").freeze
    CONFIG_PATH = File.expand_path("~/.devbox_launcher.yml").freeze
    CONFIG = YAML.load_file(CONFIG_PATH).freeze

    attr_reader :account_and_box_name, :options

    def initialize(account_and_box_name, options)
      @account_and_box_name = account_and_box_name
      @options = options
    end

    def account
      @account ||= @account_and_box_name.split("/")[0]
    end

    def start
      start_stdout, start_stderr, start_status =
        Open3.capture3(start_cmd)

      set_ssh_config!

      wait_boot

      reset_mutagen_session

      connect_mosh || connect_ssh
    end

    def start_cmd
      cmd_args_for('start')
    end

    def connect_mosh
      return if options[:mosh].nil?

      mosh_cmd = %Q(mosh #{hostname})
      system(mosh_cmd)
    end

    def connect_ssh
      return if options[:ssh].nil?

      ssh_cmd = %Q(ssh #{hostname})
      system(ssh_cmd)
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
      cmd_args_for('describe')
    end

    def set_ssh_config!
      FileUtils.touch(SSH_CONFIG_PATH)
      ssh_config = ConfigFile.new
      args = {
        "HostName" => description.ip,
        "User" => username,
        "IdentityFile" => box_config.identity_file,
      }
      args.each do |key, value|
        ssh_config.set(hostname, key, value)
      end
      ssh_config.save
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
        %Q(mutagen sync terminate --label-selector=#{label})
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
      "#{username}=#{name}"
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

    def box_name_from_config
      passed_in_box_name = @account_and_box_name.split("/")[1]

      case account_config.count
      when 0
        fail "You have to specify box configuration"
      when 1
        account_config.first[:box]
      else
        account_config[name]
      end
    end

    def name
      return @name if @name
      passed_in_box_name = @account_and_box_name.split("/")[1]

      name = passed_in_box_name.presence || box_name_from_config

      if name.blank?
        fail "box name must be given either in the CLI or in config. " \
          "See README.md."
      end

      @name = name
    end

    def hostname
      [name, username, "devbox"].join("-")
    end

    def username
      @username ||= box_config.user || account.gsub(/\W/, "_")
    end

    def account_config
      return @account_config if @account_config

      if not CONFIG.has_key?(account)
        fail "No config in #{CONFIG_PATH} found for #{account}"
      end

      @account_config = AccountConfig.new(account, CONFIG[account])
    end

    def box_config
      account_config.find_box_config(name)
    end

    def mutagen_config
      @mutagen_config ||= box_config.mutagen_config
    end

    def cmd_args_for(method)
      args = {
        project: box_config.project,
        account: account,
        zone: box_config.zone,
      }.each_with_object([]) do |(key, val), arr|
        next if val.blank?
        arr << ["--#{key}", val].join("=")
      end.join(" ")

      [
        "gcloud",
        "compute",
        "instances",
        method,
        name,
        args
      ].join(" ")
    end


  end
end
