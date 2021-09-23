module DevboxLauncher
  class BoxConfig

    DEFAULT_IDENTIFY_FILE_PATH = "~/.ssh/google_compute_engine".freeze

    attr_reader :config

    def initialize(config)
      @config = config.with_indifferent_access
    end

    def mutagen_config
      Mutagen.new(config[:mutagen])
    end

    def project
      config[:project]
    end

    def zone
      config[:zone]
    end

    def user
      config[:user]
    end

    def identity_file
      config[:identity_file] || DEFAULT_IDENTIFY_FILE_PATH
    end

  end
end
