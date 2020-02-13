#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'openssl'
require 'faraday'
require 'dotenv/load'

X_APIRADIO_UID = ENV['X_APIRADIO_UID']
SECRET_KEY = ENV['SECRET_KEY']

BASE_API_URL = "https://api2.radio.orange.com"

# CONTINENT_CODE = ARGV[0].to_s

def getJsonFromFile filepath
  file = File.open filepath
  json = JSON.load file, symbolize_names: true
  return json
end

def generateCSV(json, lang, continent)
  en_json = getJsonFromUrl("/v2/localisations/#{continent}/countries", "en-EN")
  csv_string = CSV.generate do |csv|
    header = ["Code", "Name"]
    header.insert(2, "Name (EN)") unless lang == "en-EN"
    csv << header
    json["result"].each do |item|
      # country_json = getJsonFromUrl("/v2/tops/radios/#{item["code"]}", lang)
      # country_count = country_json["paginate"]["count"]
      en_name = en_json["result"].find { |key| key["code"] == item["code"] }["name"]
      row = [item["code"],item["name"]]
      row.insert(2, en_name) unless lang == "en-EN"
      csv << row
    end
  end
  return csv_string
end

def generateHMAC request_url
  hmac_data = request_url + ":" + X_APIRADIO_UID
  hmac_key = SECRET_KEY
  digest = OpenSSL::Digest.new('sha256')
  computed_hmac = OpenSSL::HMAC.hexdigest(digest, hmac_key, hmac_data)
  return "0x#{computed_hmac}"
end

def getJsonFromUrl(request_url, lang)
  oauth_token = generateHMAC(request_url)

  api_url = BASE_API_URL + request_url

  resp = Faraday.get(api_url, nil,
    {
      'X-OAuth-Token' => oauth_token,
      'X-Apiradio-Uid' => X_APIRADIO_UID,
      'Accept' => 'application/json',
      'accept-language' => lang
    }
  )
  return JSON.parse(resp.body)
end

continents = ["AF", "AS", "EU", "NA", "SA", "OC", "AN"]

languages = ["en-EN"]

continents.each do |continent|
  puts "### #{continent}"
  languages.each do |language|
    json = getJsonFromUrl("/v2/localisations/#{continent}/countries", language)
    puts "### #{language}"
    puts ""
    puts generateCSV(json, language, continent)
    puts ""
  end
end
