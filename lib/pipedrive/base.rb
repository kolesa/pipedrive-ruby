require 'httparty'
require 'ostruct'
require 'forwardable'

module Pipedrive

  # Globally set request headers
  HEADERS = {
      "User-Agent"    => "istat24.Pipedrive.Api",
      "Accept"        => "application/json",
      "Content-Type"  => "application/x-www-form-urlencoded"
  }

  # Base class for setting HTTParty configurations globally
  class Base < OpenStruct

    include HTTParty

    base_uri 'https://api.pipedrive.com/v1'
    headers HEADERS
    format :json

    extend Forwardable
    def_delegators 'self.class', :delete, :get, :post, :put, :resource_path, :bad_response

    attr_reader :data

    # Create a new Pipedrive::Base object.
    #
    # Only used internally
    #
    # @param [Hash] attributes
    # @return [Pipedrive::Base]
    def initialize(attrs = {})
      if attrs['data']
        struct_attrs = attrs['data']

        if attrs['additional_data']
          struct_attrs.merge!(attrs['additional_data'])
        end
      else
        struct_attrs = attrs
      end

      super(struct_attrs)
    end

    # Updates the object.
    #
    # @param [Hash] opts
    # @return [Boolean]
    def update(opts = {})
      if opts.keys.include?(:api_token)
        api_token = opts.delete(:api_token)
        res = put "#{resource_path}/#{id}", :body => opts, query: {api_token: api_token}
      else
        res = put "#{resource_path}/#{id}", :body => opts
      end
      if res.success?
        res['data'] = Hash[res['data'].map {|k, v| [k.to_sym, v] }]
        @table.merge!(res['data'])
      else
        false
      end
    end

    class << self

      # Examines a bad response and raises an appropriate exception
      #
      # @param [HTTParty::Response] response
      def bad_response(response, params={})
        puts params.inspect
        if response.class == HTTParty::Response
          raise HTTParty::ResponseError, response
        end
        raise StandardError, 'Unknown error'
      end

      def new_list( attrs )
        attrs['data'].is_a?(Array) ? attrs['data'].map {|data| self.new( 'data' => data ) } : []
      end

      def all(response = nil, options={}, get_absolutely_all=false)
        res = response || get(resource_path, :query => {}.merge(options))
        if res.ok?
          data = res['data'].nil? ? [] : res['data'].map{|obj| new(obj)}
          if get_absolutely_all && res['additional_data']['pagination'] && res['additional_data']['pagination']['more_items_in_collection']
            options[:query] = options[:query].merge({:start => res['additional_data']['pagination']['next_start']})
            data += self.all(nil,options,true)
          end
          data
        else
          bad_response(res, options)
        end
      end

      def create(options = {} )
        if options.keys.include?(:api_token)
          api_token = options.delete(:api_token)
          res = post resource_path, body: options, query: {api_token: api_token}
        else
          res = post resource_path, body: options
        end
        if res.success?
          res['data'] = options.merge res['data']
          new(res)
        else
          bad_response(res,options)
        end
      end

      def find(id, options={})
        res = get "#{resource_path}/#{id}", :query => {}.merge(options)
        res.ok? ? new(res) : bad_response(res,id)
      end

      def find_by_name(name, options={})
        res = get "#{resource_path}/find", :query => { :term => name }.merge(options)
        res.ok? ? new_list(res) : bad_response(res,{:name => name}.merge(options))
      end

      def resource_path
        # The resource path should match the camelCased class name with the
        # first letter downcased.  Pipedrive API is sensitive to capitalisation
        klass = name.split('::').last
        klass[0] = klass[0].chr.downcase
        klass.end_with?('y') ? "/#{klass.chop}ies" : "/#{klass}s"
      end
    end
  end

end