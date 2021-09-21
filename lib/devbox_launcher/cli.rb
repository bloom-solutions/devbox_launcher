module DevboxLauncher
  class CLI < Thor

    WAIT_BOOT_IN_SECONDS = 10.freeze
    DEFAULT_IDENTIFY_FILE_PATH = "~/.ssh/google_compute_engine".freeze
    SSH_CONFIG_PATH = File.expand_path("~/.ssh/config").freeze
    CONFIG_PATH = File.expand_path("~/.devbox_launcher.yml").freeze
    CONFIG = YAML.load_file(CONFIG_PATH).freeze

    desc "start configured box for account", "Start a devbox by account"
    option :mosh, type: :boolean, desc: "Mosh in"
    option :ssh, type: :boolean, desc: "SSH in"

    def start(account)
      Box.new(account, options).start
    end

  end
end
