module DevboxLauncher
  class CLI < Thor

    WAIT_BOOT_IN_SECONDS = 10.freeze
    DEFAULT_IDENTIFY_FILE_PATH = "~/.ssh/google_compute_engine".freeze
    SSH_CONFIG_PATH = File.expand_path("~/.ssh/config").freeze
    CONFIG_PATH = File.expand_path("~/.devbox_launcher.yml").freeze
    CONFIG = YAML.load_file(CONFIG_PATH).freeze
    LABEL = "devbox".freeze

    desc "start configured box for account", "Start a devbox by account"
    option :mosh, type: :boolean, desc: "Mosh in"

    def start(account)
      if not CONFIG.has_key?(account)
        fail "No config in #{CONFIG_PATH} found for #{account}"
      end

      config = CONFIG[account].with_indifferent_access
      name = config[:box]

      username = account.gsub(/\W/, "_")

      puts "Starting #{name}..."

      set_account_command = %Q(gcloud config set account #{account})
      set_account_stdout, set_account_stderr, set_account_status =
        Open3.capture3(set_account_command)

      set_project_command = %Q(gcloud config set project #{config[:project]})
      set_project_stdout, set_project_stderr, set_project_status =
        Open3.capture3(set_project_command)

      start_box name, username

      wait_boot(name, username)

      hostname = hostname_for(name)

      reset_mutagen_session(
        mutagen_config: config[:mutagen],
        hostname: hostname,
      )

      if options[:mosh]
        mosh_command = %Q(mosh #{hostname})
        system(mosh_command)
      end
    end

    no_commands do
      def wait_boot(name, username, tries: 1)
        hostname = hostname_for(name)

        Net::SSH.start(hostname, username, timeout: WAIT_BOOT_IN_SECONDS) do |ssh|
          puts "[#{ssh.exec!('date').chomp}] Machine booted"
        end
      rescue Net::SSH::ConnectionTimeout, Net::SSH::Disconnect, Errno::ECONNRESET
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

      def reset_mutagen_session(mutagen_config:, hostname:)
        return if mutagen_config.nil?
        alpha_dir = mutagen_config[:alpha]
        beta_dir = mutagen_config[:beta]

        return if alpha_dir.nil? || beta_dir.nil?

        terminate_mutagen_session
        create_mutagen_session(
          alpha_dir: alpha_dir,
          beta_dir: beta_dir,
          hostname: hostname,
        )

        if OS.linux?
          watch_alpha(alpha_dir: alpha_dir)
        end
      end

      def terminate_mutagen_session
        puts "Terminating mutagen session..."
        terminate_mutagen_command =
          %Q(mutagen terminate --label-selector=#{LABEL})
        terminate_mutagen_stdout,
          terminate_mutagen_stderr,
          terminate_mutagen_status =
          Open3.capture3(terminate_mutagen_command)

        if not terminate_mutagen_status.success?
          # mutagen prints to stdout and stderr
          msg = "Failed to terminate mutagen sessions: " \
            "#{terminate_mutagen_stdout} -" \
            "#{terminate_mutagen_stderr}"
          fail msg
        end
      end

      def create_mutagen_session(alpha_dir:, beta_dir:, hostname:)
        puts "Create mutagen session syncing local #{alpha_dir} " \
          "with #{hostname} #{beta_dir}"

        create_mutagen_command = [
          "mutagen sync create",
          alpha_dir,
          "#{hostname}:#{beta_dir}",
          "--label=#{LABEL}",
        ]
        create_mutagen_command << "--watch-mode-alpha=no-watch" if OS.linux?

        create_mutagen_stdout,
          create_mutagen_stderr,
          create_mutagen_status =
          Open3.capture3(create_mutagen_command.join(" "))

        if not create_mutagen_status.success?
          # mutagen prints to stdout and stderr
          msg = "Failed to create mutagen sessions: " \
            "#{create_mutagen_stdout} -" \
            "#{create_mutagen_stderr}"
          fail msg
        end
      end

      def watch_alpha(alpha_dir:)
        watchman = Watchman.new(dir: alpha_dir)
        watchman.trigger("mutagen sync flush --label-selector=#{LABEL}")
      end

      def start_box(name, username)
        start_command = %Q(gcloud compute instances start #{name})
        start_stdout, start_stderr, start_status = Open3.capture3(start_command)

        desc = describe(name)
        ip = desc.ip

        set_ssh_config!(hostname_for(name), {
          username: username,
          ip: ip,
        })
      end

      def describe(name)
        puts "Fetching box's description..."

        describe_command = %Q(gcloud compute instances describe #{name})
        describe_stdout, describe_stderr, describe_status =
          Open3.capture3(describe_command)

        if !describe_status.success?
          msg = "Problem fetching the description of #{name}. "
          msg += "Please ensure you can call `#{describe_command}`.\n"
          msg += "Error:\n"
          msg += describe_stderr
          fail msg
        end

        Description.new(describe_stdout)
      end

      def hostname_for(name)
        [name, "devbox"].join("-")
      end
    end

  end
end
