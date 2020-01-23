module DevboxLauncher
  class Watchman

    attr_reader :dir

    def initialize(dir:)
      @dir = dir
    end

    def trigger(command)
      UNIXSocket.open(sockname) do |socket|
        root = Pathname.new(dir).expand_path.to_s
        result = RubyWatchman.query(['watch-list'], socket)
        roots = result['roots']
        if !roots.include?(root)
          # this path isn't being watched yet; try to set up watch
          result = RubyWatchman.query(['watch-project', root], socket)

          # root_restrict_files setting may prevent Watchman from working
          raise "Unable to watch #{dir}" if result.has_key?('error')
        end

        query = ['trigger', root, {
          'name' => 'mutagen-sync',
          'expression' => ['match', '**/*', 'wholename'],
          'command' => command.split(" "),
        }]
        paths = RubyWatchman.query(query, socket)

        # could return error if watch is removed
        if paths.has_key?('error')
          raise "Unable to set trigger. Error: #{paths['error']}"
        end
      end
    end

    def sockname
      sockname = RubyWatchman.load(
        %x{watchman --output-encoding=bser get-sockname}
      )['sockname']

      if !$?.exitstatus.zero?
        raise "Failed to connect to watchman. Is it running?"
      end

      sockname
    end

  end
end
