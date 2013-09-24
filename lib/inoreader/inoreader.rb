require 'net/http'
require 'json'


module InoReader

  READ = 'user/-/state/com.google/read'
  STARRED = 'user/-/state/com.google/starred'
  BROADCASTED = 'user/-/state/com.google/broadcast'
  LIKED = 'user/-/state/com.google/like'

  class Ino

    attr_accessor :token

    def initialize
      uri = URI('https://inoreader.com')
      @ino = Net::HTTP.new(uri.host, uri.port)
      @ino.use_ssl = true
    end

    def authenticate(email, password)
      response = send_request('/accounts/ClientLogin', :Email => email, :Passwd => password)
      @token = response[/Auth=.*/].split('=')[1] # this is crap!!!
    end

    def get_user_info
      send_request('/user-info')
    end

    def get_unread_counters
      send_request('/unread-count')
    end

    def stream_contents(number_of_items=nil, order=nil, start_time=nil, include=nil, exclude=nil, cont=nil)
      send_request('/stream/contents',
                   :n => number_of_items,
                   :r => order,
                   :ot => start_time,
                   :it => include,
                   :xt => exclude,
                   :c => cont)
    end

    def list_subscriptions
      send_request('/subscription/list')
    end

    def add_subscription(feed, title=nil, folder=nil)
      send_request('/subscription/edit',
                   :ac => 'subscribe',
                   :s => "feed/#{feed}",
                   :t => title,
                   :a => folder)
    end

    def edit_subscription(feed, title=nil, folder=nil)
      send_request('/subscription/edit',
                   :s => "feed/#{feed}",
                   :t => title,
                   :a => folder)
    end

    def remove_subscription(feed)
      send_request('/subscription/edit',
                   :s => "feed/#{feed}")
    end

    def list_tags
      send_request('/tag/list')
    end

    def add_tag(tag)
      send_request('/edit-tag',
                   :a => "user/-/label/#{tag}")
    end

    def edit_tag(tag, new_name)
      send_request('/rename-tag',
                   :s => tag,
                   :dest => new_name)
    end

    def remove_tag(tag)
      send_request('/disable-tag',
                   :s => tag)
    end

    def list_items
      send_request('/stream/items/ids')
    end

    def read_items(items)
      tag_items(Ino::READ, items)
    end

    def unread_items(items)
      untag_items(Ino::READ, items)
    end

    def star_items(items)
      tag_items(Ino::STARRED, items)
    end

    def unstar_items(items)
      untag_items(Ino::STARRED, items)
    end

    def broadcast_items(items)
      tag_items(Ino::BROADCASTED, items)
    end

    def unbroadcast_items(items)
      untag_items(Ino::BROADCASTED, items)
    end

    def like_items(items)
      tag_items(Ino::LIKED, items)
    end

    def unlike_items(items)
      untag_items(Ino::UNLIKED, items)
    end

    def list_stream_preferences
      send_request('/preference/stream/list')
    end

    def self.get_short_id(long_id)
      long_id[/item\/.*/].split('/')[1].to_i(base=16) # this is crap!!!
    end

    private
    def compose_query(path, url_params={})
      query = ''
      query_string = ''
      url_params.each do |param, value|
        query_string += "#{param.to_s}=#{value}&"
      end
      query += path
      query += '?' + query_string.chomp('&') unless url_params.empty?
      query
    end

    def send_request(endpoint, url_params={})
      if endpoint == '/accounts/ClientLogin'
        path = ''
      else
        path = '/reader/api/0'
      end
      query = compose_query(path + endpoint, url_params)
      request = Net::HTTP::Get.new(query)
      request['Authorization'] = "GoogleLogin auth=#{@token}" unless endpoint == '/accounts/ClientLogin'
      response = @ino.request(request)
      if response.is_a?(Net::HTTPUnauthorized)
        if response.body.empty?
          raise BadAuthentication, 'Wrong token'
        else
          raise BadAuthentication, response.body
        end
      end
      begin
        resp = JSON.parse(response.body)
      rescue JSON::ParserError
        resp = response.body
      end
      resp
    end

    def tag_items(tag, items)
      send_request('/edit-tag',
                   :a => tag,
                   :i => items.join(','))
    end

    def untag_items(tag, items)
      send_request('/edit-tag',
                   :r => tag,
                   :i => items.join(','))
    end
  end


  class InoError < StandardError
  end

  class BadAuthentication < InoError
  end
end
