require 'net/http'

module Flickr
  class Downloader
    attr_reader :storage

    def initialize(options)
      @storage = Flickr::Storage.new(options)
    end

    def download(photo_id, set_id)
      download_photo(photo_id, set_id)
      download_thumbnail(photo_id, set_id)
    end

    def download_photo(photo_id, set_id)
      return if storage.photo_exists?(photo_id, set_id)

      data = storage.load_photo_info(photo_id, set_id)
      return unless data['photo']['usage']['candownload'] == 1
      url = image_url(data)
      originalformat = data['photo']['originalformat']
      puts "fetching #{url}"

      begin
        response = http_get(url)

        if response.code == '200'
          save_photo(photo_id, set_id, originalformat, response)
        else
          puts "ERROR: #{response.class.to_s}"
        end
      rescue => e
        puts "ERROR: #{e.class}: #{e.message}"
      end
    end

    def download_thumbnail(photo_id, set_id)
      return if storage.thumbnail_exists?(photo_id, set_id)

      data = storage.load_photo_info(photo_id, set_id)
      return unless data['photo']['usage']['candownload'] == 1
      url = thumbnail_url(data)
      puts "fetching #{url}"

      begin
        response = http_get(url)

        if response.code == '200'
          save_thumbnail(photo_id, set_id, response)
        else
          puts "ERROR: #{response.code}: #{response.class.to_s}"
        end
      rescue => e
        puts "ERROR: #{e.class}: #{e.message}"
      end
    end

    def save_photo(photo_id, set_id, originalformat, response)
      destination = storage.photo_image_path(photo_id, set_id, originalformat)
      puts "saving #{destination}"

      File.open(destination, "wb") do |f|
        f.write(response.body)
      end
    end

    def save_thumbnail(photo_id, set_id, response)
      destination = storage.thumbnail_image_path(photo_id, set_id)
      puts "saving #{destination}"

      FileUtils.mkdir_p(File.dirname(destination))
      File.open(destination, "wb") do |f|
        f.write(response.body)
      end
    end

    def image_url(data)
      farm = data['photo']['farm']
      server = data['photo']['server']
      photo_id = data['photo']['id']
      originalsecret = data['photo']['originalsecret']
      originalformat = data['photo']['originalformat']

      "http://farm#{farm}.static.flickr.com/#{server}/#{photo_id}_#{originalsecret}_o.#{originalformat}"
    end

    def thumbnail_url(data)
      farm = data['photo']['farm']
      server = data['photo']['server']
      photo_id = data['photo']['id']
      secret = data['photo']['secret'] # not originalsecret

      "http://farm#{farm}.static.flickr.com/#{server}/#{photo_id}_#{secret}_q.jpg"
    end

    private

    def http_get(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      http.request(request)
    end
  end
end
