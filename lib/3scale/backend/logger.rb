module ThreeScale
  module Backend
    class Logger
      FORMAT = "%s - %s [%s] \"%s %s%s %s\" %d %s %s %s %s %s %s %s %s\n"
      ERROR_FORMAT = "%s - %s [%s] \"%s %s%s %s\" %d \"%s\" %s\n"

      def initialize(app, logger=nil)
        @app = app
        @logger = logger
      end

      def call(env)
        began_at = Time.now
        begin
          status, header, body = @app.call(env)
        rescue Exception => e
          log_error(env, 500, e.message, began_at)
          raise e
        end
        header = Rack::Utils::HeaderHash.new(header)
        body = Rack::BodyProxy.new(body) { log(env, status, header, began_at) }
        [status, header, body]
      end

      private

      def log_error(env, status, error, began_at)
        now = Time.now.getutc
        qs  = extract_query_string(env)

        logger = @logger || env['rack.errors']
        logger.write ERROR_FORMAT % [
          env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
          env["REMOTE_USER"] || "-",
          now.strftime("%d/%b/%Y %H:%M:%S %Z"),
          env["REQUEST_METHOD"],
          env["PATH_INFO"],
          qs.empty? ? "" : "?" + qs.gsub("\n",""),
          env["HTTP_VERSION"],
          status.to_s[0..3],
          error,
          now - began_at]
      end

      def log(env, status, header, began_at)
        now    = Time.now.getutc
        qs     = extract_query_string(env)
        length = extract_content_length(header)

        logger = @logger || env['rack.errors']
        logger.write FORMAT % [
          env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
          env["REMOTE_USER"] || "-",
          now.strftime("%d/%b/%Y %H:%M:%S %Z"),
          env["REQUEST_METHOD"],
          env["PATH_INFO"],
          qs.empty? ? "" : "?"+qs.gsub("\n",""),
          env["HTTP_VERSION"],
          status.to_s[0..3],
          length,
          now - began_at,
          ThreeScale::Backend::Cache.stats[:last] || "-",
          ThreeScale::Backend::Cache.stats[:count] || "-",
          ThreeScale::Backend::Cache.stats[:hits] || "-",
          ThreeScale::Backend::Memoizer.stats[:size] || "-",
          ThreeScale::Backend::Memoizer.stats[:count] || "-",
          ThreeScale::Backend::Memoizer.stats[:hits] || "-"]
      end

      def extract_content_length(headers)
        value = headers['Content-Length'] or return '-'
        value.to_s == '0' ? '-' : value
      end

      def extract_query_string(env)
        if env["REQUEST_METHOD"].to_s.upcase == "POST"
          provider_key = Rack::Request.new(env).params["provider_key"]
          qs = env["QUERY_STRING"].dup
          unless provider_key.nil?
            qs << "&" unless env["QUERY_STRING"].empty?
            qs << "provider_key=#{provider_key}"
          end
        else
          qs = env["QUERY_STRING"]
        end

        qs
      end
    end
  end
end
