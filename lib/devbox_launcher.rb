require "active_support/core_ext/hash/indifferent_access"
require "ssh-config"
require "open3"
require "thor"
require "net/ssh"
require "os"
require "ruby-watchman"
require 'socket'
require 'pathname'
require "yaml"
require "devbox_launcher/version"

module DevboxLauncher
  class Error < StandardError; end
end

require "devbox_launcher/cli"
require "devbox_launcher/watchman"
