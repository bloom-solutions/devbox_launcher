require "ssh-config"
require "open3"
require "thor"
require "net/ssh"
require "yaml"
require "devbox_launcher/version"

module DevboxLauncher
  class Error < StandardError; end
end

require "devbox_launcher/cli"