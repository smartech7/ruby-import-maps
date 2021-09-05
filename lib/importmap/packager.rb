require "net/http"
require "uri"
require "json"

class Importmap::Packager
  Error        = Class.new(StandardError)
  HTTPError    = Class.new(Error)
  ServiceError = Error.new(Error)

  singleton_class.attr_accessor :endpoint
  self.endpoint = URI("https://api.jspm.io/generate")

  def initialize(importmap_path = "config/importmap.rb")
    @importmap_path = importmap_path
  end

  def import(*packages, env: "production", from: "jspm")
    response = post_json({
      "install"      => Array(packages), 
      "flattenScope" => true,
      "env"          => [ "browser", "module", env ],
      "provider"     => from.to_s,
    })

    case response.code
    when "200"        then extract_parsed_imports(response)
    when "404", "401" then nil
    else                   handle_failure_response(response)
    end
  end

  def pin_for(package, url)
    %(pin "#{package}", to: "#{url}")
  end

  def packaged?(package)
    importmap.match(/^pin "#{package}".*$/)
  end

  private
    def extract_parsed_imports(response)
      JSON.parse(response.body).dig("map", "imports")
    end
      
    def handle_failure_response(response)
      if error_message = parse_service_error(response)
        raise ServiceError, error_message
      else
        raise HTTPError, "Unexpected response code (#{response.code})"
      end
    end
  
    def parse_service_error(response)
      JSON.parse(response.body.to_s)["error"]
    rescue JSON::ParserError
      nil
    end

    def post_json(body)
      Net::HTTP.post(self.class.endpoint, body.to_json, { "Content-Type" => "application/json" })
    rescue => error
      raise HTTPError, "Unexpected transport error (#{error.class}: #{error.message})"
    end

    def importmap
      @importmap ||= File.read(@importmap_path)
    end
end
