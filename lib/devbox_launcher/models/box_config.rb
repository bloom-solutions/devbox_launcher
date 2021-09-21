module DevboxLauncher
  class BoxConfig

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

  end
end
