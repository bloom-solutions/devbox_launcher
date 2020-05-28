module DevboxLauncher
  class Mutagen

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def configured?
      [config, alpha_dir, beta_dir].none?(&:nil?)
    end

    def alpha_dir
      config[:alpha]
    end

    def beta_dir
      config[:beta]
    end

  end
end
