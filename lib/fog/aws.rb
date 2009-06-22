require File.dirname(__FILE__) + '/aws/simpledb'
require File.dirname(__FILE__) + '/aws/s3'

require 'rubygems'
require 'openssl'
require 'socket'
require 'uri'

module Fog
  module AWS
    class Connection

      def initialize(url)
        @uri = URI.parse(url)
        @connection = TCPSocket.open(@uri.host, @uri.port)
        if @uri.scheme == 'https'
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
          @connection = OpenSSL::SSL::SSLSocket.new(@connection, @ssl_context)
          @connection.sync_close = true
          @connection.connect
        end
      end

      def request(params)
        params = {
          :headers => {}
        }.merge(params)
        uri = URI.parse(params[:url])
        path = "#{uri.path}"
        path << "?#{uri.query}" if uri.query
        host = "#{uri.host}"
        host << ":#{uri.port}" if uri.scheme == "http" && uri.port != 80
        host << ":#{uri.port}" if uri.scheme == "https" && uri.port != 443

        request = "#{params[:method]} #{path} HTTP/1.1\r\n"
        params[:headers]['Host'] = uri.host
        params[:headers]['Content-Length'] = (params[:body].length) if params[:body]
        for key, value in params[:headers]
          request << "#{key}: #{value}\r\n"
        end
        request << "\r\n"
        request << params[:body] if params[:body]
        @connection.write(request)

        response = AWS::Response.new
        @connection.readline =~ /\AHTTP\/1.1 ([\d]{3})/
        response.status = $1.to_i
        while true
          data = @connection.readline
          break if data == "\r\n"
          if header = data.match(/(.*):\s(.*)\r\n/)
            response.headers[header[1]] = header[2]
          end
        end
        if response.headers['Content-Length']
          content_length = response.headers['Content-Length'].to_i
          response.body << @connection.read(content_length)
        elsif response.headers['Transfer-Encoding'] == 'chunked'
          while true
            @connection.readline =~ /([a-f0-9]*)\r\n/i
            chunk_size = $1.to_i(16) + 2  # 2 = "/r/n".length
            response.body << @connection.read(chunk_size)
            break if $1.to_i(16) == 0
          end
        end
        response
      end

    end

    class Response

      attr_accessor :status, :headers, :body

      def initialize
        @body = ''
        @headers = {}
      end

    end


  end
end
