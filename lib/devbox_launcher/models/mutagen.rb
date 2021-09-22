module DevboxLauncher
  class Mutagen

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def configured?
      return false if config.nil?
      [alpha_dir, beta_dir].all?(&:present?)
    end

    def alpha_dir
      config[:alpha]
    end

    def beta_dir
      config[:beta]
    end

  end
end
