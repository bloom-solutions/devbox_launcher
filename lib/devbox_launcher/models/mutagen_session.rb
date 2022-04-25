module DevboxLauncher
  class MutagenSession

    attr_reader :label, :config, :hostname

    def initialize(label:, config:, hostname:)
      @label = label
      @config = config
      @hostname = hostname
    end

    def create
      puts "Create mutagen session syncing local " \
        "#{config.alpha_dir} with " \
        "#{hostname} #{config.beta_dir}"

      create_stdout,
        create_stderr,
        create_status =
        Open3.capture3(create_cmd)

      if not create_status.success?
        # mutagen prints to stdout and stderr
        msg = "Failed to create mutagen sessions: " \
          "#{create_stdout} -" \
          "#{create_stderr}"
        fail msg
      end
    end

    def linux?
      OS.linux?
    end

    def create_cmd
      str = [
        "mutagen sync create",
        config.alpha_dir,
        "#{hostname}:#{config.beta_dir}",
        "--label=#{label}",
        "--sync-mode=two-way-resolved",
        "--ignore-vcs",
        "--ignore=.DS_Store"
      ]
      str << "--watch-mode-alpha=no-watch" if linux?
      str.join(" ")
    end

    def terminate_cmd
      %Q(mutagen sync terminate --label-selector=#{label})
    end

    def terminate
      puts "Terminating mutagen session..."
      terminate_stdout,
        terminate_stderr,
        terminate_status =
        Open3.capture3(terminate_cmd)

      if not terminate_status.success?
        # mutagen prints to stdout and stderr
        msg = "Failed to terminate mutagen sessions: " \
          "#{terminate_stdout} -" \
          "#{terminate_stderr}"
        fail msg
      end
    end

    def watch_alpha
      watchman.trigger("mutagen sync flush --label-selector=#{label}")
    end

    def watchman
      @watchman ||= Watchman.new(dir: config.alpha_dir)
    end

    def reset
      return if !config.configured?

      terminate
      create
      watch_alpha if linux?
    end

  end
end
