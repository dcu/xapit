require 'xapian'
require 'digest/sha1'
require 'rack'
require 'json'
require 'net/http'

module Xapit
  class << self
    attr_reader :config

    def reset_config
      @database = nil
      @config = {
        :spelling => true,
        :stemming => "english"
      }
    end

    def database
      if config[:server]
        @database ||= Xapit::Client::RemoteDatabase.new(config[:server])
      else
        @database ||= Xapit::Server::Database.new(config[:database_path], config[:template_path])
      end
    end

    def load_config(filename, environment)
      yaml = YAML.load_file(filename)[environment.to_s]
      raise ArgumentError, "The #{environment} environment does not exist in #{filename}" if yaml.nil?
      yaml.each { |k, v| config[k.to_sym] = v }
    end

    def value_index(type, attribute)
      Zlib.crc32(["xapit", type, attribute].join) % 99999999 # TODO: Figure out the true max of a xapian value index
    end

    def facet_identifier(attribute, value)
      Digest::SHA1.hexdigest(["xapit", attribute, value].join)[0..6]
    end

    def search(*args)
      Xapit::Client::Collection.new.not_in_classes("FacetOption").search(*args)
    end

    def serialize_value(value)
      if value.kind_of?(Time)
        Xapian.sortable_serialise(value.to_i)
      elsif value.kind_of?(Numeric) || value.to_s =~ /^[0-9]+$/
        Xapian.sortable_serialise(value.to_f)
      else
        value.to_s.downcase
      end
    end
  end

  reset_config
end

require 'xapit/server/database'
require 'xapit/server/query'
require 'xapit/server/indexer'
require 'xapit/server/app'
require 'xapit/client/membership'
require 'xapit/client/index_builder'
require 'xapit/client/collection'
require 'xapit/client/facet'
require 'xapit/client/facet_option'
require 'xapit/client/remote_database'
require 'xapit/client/model_adapters/abstract_model_adapter'
require 'xapit/client/model_adapters/default_model_adapter'
require 'xapit/client/model_adapters/active_record_adapter'
