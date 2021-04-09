require "http/client"
require "myhtml"
require "json"

module Duo
    class Client
        @sid : String
        @txid : String
        @akey : String

        def initialize(
            @host : String,
            @duo_sig : String,
            @app_sig : String,
            @parent_url : String,
            @user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36")

            @cookies = HTTP::Cookies.new

            url_params = URI::Params.encode({
                "tx" => @duo_sig,
                "parent" => @parent_url,
                "v" => "2.6"
            })

            @auth_uri = URI.new("https", @host, nil, "/frame/web/v1/auth", query: url_params)
            @token_uri = URI.new("https", @host, nil, "/frame/prompt")

            @sid = ""
            @txid = ""
            @akey = ""
        end

        def initialize(
            host : String,
            sig_request : String,
            parent_url : String)

            sr = sig_request.split(":")

            if sr.size != 2
                raise "sig_request was malformed: #{sig_request}"
            end

            initialize(host, sr[0], sr[1], parent_url)
        end

        def self.from_iframe(duo_iframe : Myhtml::Node, parent_url : String) : Client
            sr_attrib = duo_iframe.attribute_by("data-sig-request")
            if sr_attrib.nil?
                raise "Failed to find duo data-sig-request attribute in iframe"
            end

            host_attrib = duo_iframe.attribute_by("data-host")
            if(host_attrib.nil?)
                raise "Failed to find duo data-host attribute in iframe"
            end

            return Client.new(host_attrib, sr_attrib, parent_url)
        end

        def fetch_iframe()
            form_data = URI::Params.build do |form|
                form.add "tx", @duo_sig
                form.add "parent", @parent_url
                form.add "java_version", ""
                form.add "flash_version", ""
                form.add "screen_resolution_width", "1680"
                form.add "screen_resolution_height", "1050"
                form.add "color_depth", "24"
                form.add "is_cef_browser", "false"
                form.add "is_ipad_os", "false"
                form.add "is_ie_compatibility_mode", ""
                form.add "acting_ie_version", ""
                form.add "react_support", "true"
                form.add "react_support_error_message", ""
            end

            headers = HTTP::Headers {
                "Host" => @host,
                "User-Agent" => @user_agent,
                "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language" => "en-US,en;q=0.5",
                "Referer" => @auth_uri.to_s,
                "Content-Type" => "application/x-www-form-urlencoded",
                "Origin" => @host,
                "DNT" => "1",
                "Connection" => "keep-alive",
                "Upgrade-Insecure-Requests" => "1",
                "Pragma" => "no-cache",
                "Cache-Control" => "no-cache",
            }


            # post to duo to get api secret
            response = HTTP::Client.post(@auth_uri, headers, form_data)

            duo_auth_page = Myhtml::Parser.new(response.body)

            @sid = duo_auth_page.css("input[type=hidden][name=sid]").to_a.pop.attribute_by("value").not_nil!
            @txid = duo_auth_page.css("input[type=hidden][name=txid]").to_a.pop.attribute_by("value").not_nil!
            @akey = duo_auth_page.css("input[type=hidden][name=akey]").to_a.pop.attribute_by("value").not_nil!
        end

        def start_session()
            form_data = URI::Params.build do |form|
                form.add "sid", @sid
                form.add "akey", @akey
                form.add "txid", @txid
                form.add "response_timeout", "15"
                form.add "parent", @parent_url
                form.add "duo_app_url", "https://127.0.0.1/report"
                form.add "eh_service_url", "eh_service_url: https://2.endpointhealth.duosecurity.com/v1/healthapp/device/health?_req_trace_group=29b8baf8566cbd01af647757%2C69a8db12efa2bb01504481ff"
                form.add "eh_download_link", "https://dl.duosecurity.com/DuoDeviceHealth-latest.dmg"
                form.add "is_silent_collection", "true"
            end

            headers = HTTP::Headers {
                "Host" => @host,
                "User-Agent" => @user_agent,
                "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language" => "en-US,en;q=0.5",
                "Referer" => @auth_uri.to_s,
                "Content-Type" => "application/x-www-form-urlencoded",
                "Origin" => "https://#{@host}",
                "DNT" => "1",
                "Connection" => "keep-alive",
                "Upgrade-Insecure-Requests" => "1",
                "Pragma" => "no-cache",
                "Cache-Control" => "no-cache",
            }

            response = HTTP::Client.post(@auth_uri, headers, form_data)

            @cookies.fill_from_client_headers(response.headers)
        end

        def submit_token(duo_device : String, hotp_token : String)
            @duo_device = duo_device
            @hotp_token = hotp_token

            form_data = URI::Params.build do |form|
                form.add "sid", @sid
                form.add "device", duo_device
                form.add "factor", "Passcode"
                form.add "dampen_choice", "true"
                form.add "passcode", hotp_token
                form.add "out_of_date", "False"
                form.add "days_out_of_date", "0"
                form.add "days_to_block", "None"
            end

            duo_hotp_headers = HTTP::Headers {
                "Host" => "api-6bfb7da1.duosecurity.com",
                "User-Agent" => @user_agent,
                "Accept" => "text/plain, */*; q=0.01",
                "Accept-Language" => "en-US,en;q=0.5",
                "Referer" => @token_uri.to_s,
                "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
                "X-Requested-With" => "XMLHttpRequest",
                "Origin" => @host,
                "DNT" => "1",
                "Connection" => "keep-alive",
                "Pragma" => "no-cache",
                "Cache-Control" => "no-cache",
            }

            @cookies.add_request_headers(duo_hotp_headers)

            response = HTTP::Client.post(@token_uri, duo_hotp_headers, form_data)

            prompt_response = Resp(PromptResp).from_json(response.body)
            if prompt_response.response.nil?
                raise "Duo prompt request for device #{@duo_device} with token #{@hotp_token} failed: #{prompt_response.message}"
            end

            @txid = prompt_response.response.not_nil!.txid
        end

        def fetch_status() : Resp(StatusResp)
            duo_status_uri = URI.new("https", @host, nil, "/frame/status")

            form_data = URI::Params.build do |form|
                form.add "sid", @sid
                form.add "txid", @txid
            end

            duo_hotp_headers = HTTP::Headers {
                "Host" => @host,
                "User-Agent" => @user_agent,
                "Accept" => "text/plain, */*; q=0.01",
                "Accept-Language" => "en-US,en;q=0.5",
                "Referer" => @token_uri.to_s,
                "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
                "X-Requested-With" => "XMLHttpRequest",
                "Origin" => "https://#{@host}",
                "DNT" => "1",
                "Connection" => "keep-alive",
                "Pragma" => "no-cache",
                "Cache-Control" => "no-cache",
            }

            @cookies.add_request_headers(duo_hotp_headers)

            response = HTTP::Client.post(duo_status_uri, duo_hotp_headers, form_data)

            @cookies.fill_from_client_headers(response.headers)

            status_response = Resp(StatusResp).from_json(response.body)

            # TODO: move this logic to the big calling method
            if status_response.response.nil? || status_response.response.not_nil!.result_url.nil?
                raise "Duo status request for device #{@duo_device} with token #{@hotp_token} failed: #{status_response.message}"
            end

            return status_response
        end

        def fetch_result(result_url : String) : Resp(ResultResp)
            duo_result_uri = URI.new("https", @host, nil, result_url)

            form_data = URI::Params.build do |form|
                form.add "sid", @sid
            end

            duo_result_headers = HTTP::Headers {
                "Host" => @host,
                "User-Agent" => @user_agent,
                "Accept" => "text/plain, */*; q=0.01",
                "Accept-Language" => "en-US,en;q=0.5",
                "Referer" => @token_uri.to_s,
                "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
                "X-Requested-With" => "XMLHttpRequest",
                "Origin" => "https://#{@host}",
                "DNT" => "1",
                "Connection" => "keep-alive",
                "Pragma" => "no-cache",
                "Cache-Control" => "no-cache",
            }

            @cookies.add_request_headers(duo_result_headers)

            response = HTTP::Client.post(duo_result_uri, duo_result_headers, form_data)

            duo_result = Resp(ResultResp).from_json(response.body)
            if duo_result.response.nil?
                raise "Duo result request failed: #{duo_result.message}"
            end

            return duo_result
        end
    end

    class Resp(T)
        include JSON::Serializable

        property stat : String
        property response : T | Nil
        property message : String | Nil
    end

    class PromptResp
        include JSON::Serializable
        
        property txid : String
    end

    class StatusResp
        include JSON::Serializable

        property status : String
        property status_code : String
        property result : String
        property result_url : String | Nil
        property reason : String
        property parent : String | Nil
    end

    class ResultResp
        include JSON::Serializable
        
        property cookie : String
        property parent : String
    end
end
