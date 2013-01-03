module ThreeScale
  module Backend
    
    class Logger < Rack::CommonLogger
      def log(env, status, header, began_at)
        now = Time.now.getutc
        length = extract_content_length(header)
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

        logger = @logger || env['rack.errors']
        logger.write FORMAT % [
          env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
          env["REMOTE_USER"] || "-",
          now.strftime("%d/%b/%Y %H:%M:%S %Z"),
          env["REQUEST_METHOD"],
          env["PATH_INFO"],
          qs.empty? ? "" : "?"+qs,
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
    end
  end
end
