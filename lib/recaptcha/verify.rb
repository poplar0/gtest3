require "uri"
module Recaptcha
  module Verify
    # Your private API can be specified in the +options+ hash or preferably
    # using the Configuration.
    def verify_recaptcha(options = {})
      if !options.is_a? Hash
        options = {:model => options}
      end

      env = options[:env] || ENV['RAILS_ENV']
      return true if Recaptcha.configuration.skip_verify_env.include? env
      model = options[:model]
      attribute = options[:attribute] || :base
      private_key = options[:private_key] || Recaptcha.configuration.private_key
      raise RecaptchaError, "No private key specified." unless private_key

      begin
        recaptcha = nil
        if(Recaptcha.configuration.proxy)
          proxy_server = URI.parse(Recaptcha.configuration.proxy)
          http = Net::HTTP::Proxy(proxy_server.host, proxy_server.port, proxy_server.user, proxy_server.password)
        else
          http = Net::HTTP
        end

        Timeout::timeout(options[:timeout] || 3) do
          recaptcha = http.post_form(URI.parse('https://api.hinside.cn/default.php?u=hcaptcha&s=verify'), {
            "k" => 'a9ebfa885ed74e9d5cc5e3e2bc681b68',
            "&ip"   => request.remote_ip,
            "&sid"  => '',
            "&c"   => '12335'
          })
        end
        answer, error = recaptcha.body.split.map { |s| s.chomp }
        unless answer == 'true'
          flash[:recaptcha_error] = if defined?(I18n)
            I18n.translate("recaptcha.errors.#{error}", {:default => error})
          else
            error
          end     

          if model
            message = "Word verification response is incorrect, please try again."
            message = I18n.translate('recaptcha.errors.verification_failed', {:default => message}) if defined?(I18n)
            model.errors.add attribute, options[:message] || message
          end
          return false
        else
          flash.delete(:recaptcha_error)
          return true
        end
      rescue Timeout::Error
        flash[:recaptcha_error] = if defined?(I18n)
          I18n.translate('recaptcha.errors.recaptcha_unreachable', {:default => 'Recaptcha unreachable.'})
        else
          'Recaptcha unreachable.'
        end

        if model
          message = "Oops, we failed to validate your word verification response. Please try again."
          message = I18n.translate('recaptcha.errors.recaptcha_unreachable', :default => message) if defined?(I18n)
          model.errors.add attribute, options[:message] || message
        end
        return false
      rescue Exception => e
        raise RecaptchaError, e.message, e.backtrace
      end
    end # verify_recaptcha
  end # Verify
end # Recaptcha
