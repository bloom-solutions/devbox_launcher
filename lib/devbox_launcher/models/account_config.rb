module DevboxLauncher
  class AccountConfig

    attr_reader :account_name

    def initialize(account_name, config)
      @account_name = account_name
      @config = config
    end

    def find_box_config(box_name)
      box_config = @config.find { |c| c["box"] == box_name }

      if box_config.nil?
        fail "No box config found for #{box_name} under account #{account_name}"
      end

      BoxConfig.new(box_config)
    end

  end
end
