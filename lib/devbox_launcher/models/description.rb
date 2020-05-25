module DevboxLauncher
  class Description

    def initialize(yaml)
      @desc = YAML.load(yaml)
    end

    def ip
      return @ip if @ip
      network_interface = network_interfaces.first
      access_configs = network_interface["accessConfigs"]

      access_config = access_configs.find do |c|
        c["kind"] == "compute#accessConfig"
      end
      @ip = access_config["natIP"]
    end

    def status
      @status ||= @desc["status"]
    end

    def network_interfaces
      @network_interfaces ||= @desc["networkInterfaces"]
    end

    def running?
      status == "RUNNING"
    end

  end
end
