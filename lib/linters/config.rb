require "yaml"

module Linters
  class Config
    def initialize(content:, default_config_path:)
      @content = content
      @default_config_path = default_config_path
    end

    def to_yaml
      merge.to_yaml
    end

    def to_json
      merge.to_json
    end

    private

    attr_reader :content, :default_config_path

    def merge
      deep_merger = ->(_key, hash1, hash2) do
        if Hash === hash1 && Hash === hash2
          hash1.merge(hash2, &deep_merger)
        else
          hash2
        end
      end

      default_config.merge(custom_config, &deep_merger)
    end

    def custom_config
      YAML.safe_load(content, [Regexp, Symbol]) || {}
    end

    def default_config
      YAML.safe_load(default_content, [Regexp, Symbol])
    end

    def default_content
      File.read(default_config_path)
    end
  end
end
