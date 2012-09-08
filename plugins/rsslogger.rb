=begin
Plugin: RSS Logger
Description: Logs any RSS feed as a digest and checks for new posts for the current day
Author: [Brett Terpstra](http://brettterpstra.com)
Configuration:
  feeds: [ "feed url 1" , "feed url 2", ... ]
  tags: "@social @rss"
Notes:
  - rss_feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`
  - rss_tags are tags you want to add to every entry, e.g. "@social @rss"
=end

config = {
  'description' => ['Logs any RSS feed as a digest and checks for new posts for the current day',
                    'feeds is an array of feeds separated by commas, a single feed is fine, but it should be inside of brackets `[]`',
                    'tags are tags you want to add to every entry, e.g. "@social @rss"'],
  'feeds' => [],
  'tags' => '@social @rss'
}
$slog.register_plugin({ 'class' => 'RSSLogger', 'config' => config })

class RSSLogger < Slogger
  def do_log
    feeds = []
    if @config.key?(self.class.name)
      @rssconfig = @config[self.class.name]
      if !@rssconfig.key?('feeds') || @rssconfig['feeds'] == []
        @log.warn("RSS feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
        return
      else
        feeds = @rssconfig['feeds']
      end
    else
      @log.warn("RSS2 feeds have not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging rss posts for feeds #{feeds.join(', ')}")

    feeds.each do |rss_feed|
      retries = 0
      success = false
      until success
        if parse_feed(rss_feed)
          success = true
        else
          break if $options[:max_retries] == retries
          retries += 1
          @log.error("Error parsing #{rss_feed}, retrying (#{retries}/#{$options[:max_retries]})")
          sleep 2
        end
      end

      unless success
        @log.fatal("Could not parse feed #{rss_feed}")
      end
    end
  end

  def parse_feed(rss_feed)

    tags = @rssconfig['tags'] || ''
    tags = "\n\n#{tags}\n" unless tags == ''

    today = @timespan
    begin
      rss_content = ""
      open(rss_feed) do |f|
        rss_content = f.read
      end

      rss = RSS::Parser.parse(rss_content, false)
      feed_items = []
      rss.items.each { |item|
        item_date = Time.parse(item.date.to_s)
        if item_date > today
          feed_items.push("* [#{item.title.gsub(/\n+/,' ').strip}](#{item.link})")
        else
          break
        end
      }

      options = {}
      options['content'] = "## #{rss.title.gsub(/\n+/,' ').strip}\n\n#{feed_items.reverse.join("\n")}#{tags}"
      options['datestamp'] = item.date.utc.iso8601 rescue item.dc_date.utc.iso8601
      options['starred'] = starred
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
      sl = DayOne.new
      sl.to_dayone(options)
    rescue Exception => e
      p e
      return false
    end
    return true
  end

  def permalink(uri,redirect_count=0)
    max_redirects = 10
    options = {}
    url = URI.parse(uri)
    http = Net::HTTP.new(url.host, url.port)
    begin
      request = Net::HTTP::Get.new(url.request_uri)
      response = http.request(request)
      response['location'].gsub(/\?utm.*/,'')
    rescue
      puts "Error expanding #{uri}"
      uri
    end
  end
end
