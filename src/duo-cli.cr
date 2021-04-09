require "yaml"
require "crotp"

require "./duo-client"

class Config
    include YAML::Serializable

    property duo_device : String  # "phone1" duo device name like
    property hotp_secret : String # "c4819521bac85efa92bacce03911ea" NOT in base32
    property hotp_count : Int32   # "1" number of previous hotp codes generated
    property parent_url : String  # "https://cas.uni.edu/cas/login?param=value" url of the iframe's parent page
    property duo_host : String    # "api-7cff7da4.duosecurity.com" the hostname of the iframe
    property sig_request : String # "TX|ALPH4NUM3RIC|ALPH4NUM3RIC:APP|ALPH4NUM3RIC|ALPH4NUM3RIC"
end

config_path = ARGV[0]? || "config.yml"

if !File.exists?(config_path)
    raise "Failed to find config file at #{config_path}"
end

config_string = File.read(config_path)
config = Config.from_yaml(config_string)

dc = Duo::Client.new(config.duo_host, config.sig_request, config.parent_url)
dc.fetch_iframe
dc.start_session

hotp = CrOTP::HOTP.new(config.hotp_secret)
hotp_token = hotp.generate(config.hotp_count)
config.hotp_count += 1
File.write(config_path, config.to_yaml, mode: "w")

dc.submit_token(config.duo_device, hotp_token)
duo_status = dc.fetch_status()
duo_result = dc.fetch_result(duo_status.response.not_nil!.result_url.not_nil!)

puts duo_result.to_json