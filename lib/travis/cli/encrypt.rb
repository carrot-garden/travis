# encoding: utf-8
require 'travis/cli'
require 'yaml'

module Travis
  module CLI
    class Encrypt < RepoCommand
      attr_accessor :config_key

      on('--add [KEY]', 'adds it to .travis.yml under KEY (default: env.global)') do |c, value|
        c.config_key = value || 'env.global'
      end

      on('-s', '--[no-]split', 'treat each line as a separate input')

      def run(*args)
        if args.first =~ %r{\w+/\w+}
          warn "WARNING: The name of the repository is now passed to the command with the -r option:"
          warn "    #{command("encrypt [...] -r #{args.first}")}"
          warn "  If you tried to pass the name of the repository as the first argument, you"
          warn "  probably won't get the results you wanted.\n"
        end

        data = args.join(" ")

        if data.empty?
          say color("Reading from stdin, press Ctrl+D when done", :info) if $stdin.tty?
          data = $stdin.read
        end

        data = split? ? data.split("\n") : [data]
        encrypted = data.map { |data| repository.encrypt(data) }

        if config_key
          set_config encrypted.map { |e| { 'secure' => e } }
          File.write(travis_yaml, travis_config.to_yaml)
        else
          list = encrypted.map { |data| format(data.inspect, "  secure: %s") }
          say(list.join("\n"), template(__FILE__), :none)
        end
      end

      private

        def travis_config
          @travis_config ||= begin
            payload = YAML.load_file(travis_yaml)
            payload.respond_to?(:to_hash) ? payload.to_hash : {}
          end
        end

        def set_config(result)
          parent_config[last_key] = merge_config(result)
        end

        def merge_config(result)
          case subconfig = parent_config[last_key]
          when nil   then result.size == 1 ? result.first : result
          when Array then subconfig + result
          else            result.unshift(subconfig)
          end
        end

        def subconfig
        end

        def key_chain
          @key_chain ||= config_key.split('.')
        end

        def last_key
          key_chain.last
        end

        def parent_config
          @parent_config ||= traverse_config(travis_config, *key_chain[0..-2])
        end

        def traverse_config(hash, key = nil, *rest)
          return hash unless key

          hash[key] = case value = hash[key]
                      when nil  then {}
                      when Hash then value
                      else { 'matrix' => Array(value) }
                      end

          traverse_config(hash[key], *rest)
        end

        def travis_yaml(dir = Dir.pwd)
          path = File.expand_path('.travis.yml', dir)
          if File.exist? path
            path
          else
            parent = File.expand_path('..', dir)
            error "no .travis.yml found" if parent == dir
            travis_yaml(parent)
          end
        end
    end
  end
end

__END__
Please add the following to your <[[ color('.travis.yml', :info) ]]> file:

%s

Pro Tip: You can add it automatically by running with <[[ color('--add', :info) ]]>.

