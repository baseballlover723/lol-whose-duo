REQUEST_BASE = ".api.pvp.net"
NUMBER_OF_HISTORY_GAMES = ENV["NUMBER_OF_HISTORY_GAMES"].to_i
NUMBER_OF_DUPLICATE_KEYS = ENV["NUMBER_OF_DUPLICATE_KEYS"].to_i
REGION_TRANSLATOR = {br: "BR1", eune: "EUN1", euw: "EUW1", jp: "JP1", kr: "KR", lan: "LA1", las: "LA2",
                     na: "NA1", oce: "OC1", ru: "RU", tr: "TR1"}.with_indifferent_access
RANKED_QUEUES = ["RANKED_FLEX_SR", "RANKED_SOLO_5x5", "RANKED_TEAM_3x3", "RANKED_TEAM_5x5", "TEAM_BUILDER_DRAFT_RANKED_5x5", "TEAM_BUILDER_RANKED_SOLO"]
KEY_SLEEP_TIME = (1.4 * NUMBER_OF_DUPLICATE_KEYS).seconds
RETRY_SLEEP_TIME = 0.5
KEYS = {}.with_indifferent_access

def setup
  threads = []
  keys = []
  ENV["RIOT_API_KEYS"].split(" ").each do |key|
    keys << key
  end
  ENV["UNSTABLE_RIOT_API_KEYS"].split(" ").each do |key|
    keys << key
  end

  keys.each do |key|
    threads << Thread.new do
      region = "global"
      path = "/api/lol/static-data/na/v1.2/versions"
      uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                             path: path, query: {api_key: key}.to_query)
      response = HTTParty.get(uri)
      if response.code == 403
        keys.delete key
        print "key: '#{key}' is not valid\n"
      else
        print "key '#{key}' got a #{response.code}" if response.code != 200
      end
    end
  end
  threads.each(&:join)

  REGION_TRANSLATOR.each_key do |region|
    region_queue = Queue.new
    NUMBER_OF_DUPLICATE_KEYS.times do
      keys.each do |key|
        region_queue << key
      end
    end
    KEYS[region] = region_queue
  end
  print "#{KEYS[:na].length} valid keys, #{keys.length} unique keys. Done verifiying keys\n"
end

setup

class MainController < ApplicationController
  def index
  end

  def search
    redirect_to lookup_path(region: params.require(:region), username: params.require(:username))
  end

  def lookup
    @threads = []
    @errors = []
    @failed_api_keys = Hash.new(0)
    @key_uses = Hash.new(0)
    @region = params.require(:region)
    @username = params.require(:username)
    @id = get_summoner_id @region, @username
    @groups = {}
    @number_of_games = {}
    return unless @errors.empty?

    gon.id = @id.summoner_id
    # Thread.new do
    #   sleep 2
    #   puts "send to client"
    #   game = @id.games.first
    #   ActionCable.server.broadcast(
    #       @id.summoner_id.to_s,
    #       summoner: @id,
    #       game: game,
    #       summoners: game.summoners
    #   )
    # end
    current_game = get_current_game @region, @id
    return unless @errors.empty?

    @summoners = get_current_game_participants @region, current_game
    team_1_ids = []
    team_2_ids = []
    current_game["participants"].each do |p|
      team_1_ids << p["summonerId"].to_s if p["teamId"] == 100
      team_2_ids << p["summonerId"].to_s if p["teamId"] == 200
    end
    @summoners.each do |summoner|
      @groups[summoner] = Hash.new(0)
      @number_of_games[summoner] = 0
    end
    @summoners.each do |summoner|
      other_ids = team_1_ids.include?(summoner.summoner_id) ? team_1_ids : team_2_ids
      @threads << Thread.new do
        check_match_history(@region, summoner, other_ids.reject { |p| summoner.summoner_id == p })
      end
    end
    @threads.each(&:join)

    unless @failed_api_keys.empty?
      percent_fail = {}
      @failed_api_keys.each do |key, fails|
        print "Fails #{key}: #{fails} / #{@key_uses[key]}\n"
        percent_fail[key] = "#{fails} / #{@key_uses[key]}"
      end
      @errors << {failed_api_keys: percent_fail}
    end
  end

  def get_key(region)
    key = KEYS[region].pop
    @key_uses[key] += 1
    # print "popped #{key} off of the #{region} queue, #{KEYS[region].size} keys left\n"
    Thread.new do
      sleep KEY_SLEEP_TIME
      KEYS[region] << key
      # print "readded key: #{key} to the #{region} queue, now #{KEYS[region].size} in queue\n"
    end
    key
  end

  def get_summoner_id(region, username)
    id_path1 = "/api/lol/"
    id_path2 = "/v1.4/summoner/by-name/"

    db_username = Summoner.where(region: region, stripped_username: username.gsub(/\s+/, "").downcase)[0]
    return db_username if db_username
    print "asking riot for region: #{region}, username: #{username}'s id\n"
    key = get_key region
    id_uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                              path: id_path1 + region + id_path2 + username.gsub(/\s+/, ""),
                              query: {api_key: key}.to_query)
    json = HTTParty.get(id_uri)
    unless json.code == 200
      @errors << "Summoner '#{username}'' doesn't exist on #{region} server"
      return
    end
    if json[username.gsub(/\s+/, "").downcase]
      Summoner.create(region: region, stripped_username: username.gsub(/\s+/, "").downcase, username: json[username.gsub(/\s+/, "").downcase]["name"], summoner_id: json[username.gsub(/\s+/, "").downcase]["id"])
    end
  end

  # https://na.api.pvp.net/observer-mode/rest/consumer/getSpectatorGameInfo/NA1/78691395?api_key=f5c821d7-fc96-47f3-914d-7026a8525eee
  def get_current_game(region, summoner, retrys = 0)
    current_game_path1 = "/observer-mode/rest/consumer/getSpectatorGameInfo/"
    current_game_uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                                        path: current_game_path1 + REGION_TRANSLATOR[region] + "/" + summoner.summoner_id,
                                        query: {api_key: get_key(region)}.to_query)
    json = HTTParty.get(current_game_uri)
    unless json.code == 200
      if json.code == 404
        @errors << "'#{summoner.username}' isn't currently in a game"
        return json
      end
      if retrys < 3
        return get_current_game region, summoner, retrys + 1
      end
      @errors << "Error checking to see if '#{summoner.username}' is currently in a game. Try again a little bit."
      return json
    end

    unless Game.exists?(game_id: json["gameId"])
      summoners = get_current_game_participants region, json
      Game.create(game_id: json["gameId"], summoners: summoners)
    end
    json
  end

  def get_current_game_participants(region, game)
    summoners = []
    game["participants"].each do |participant|
      summoner = Summoner.where(summoner_id: participant["summonerId"])[0]
      if summoner
        summoner.update(username: participant["summonerName"],
                        stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase)
        summoners << summoner
      else
        summoners << Summoner.create(username: participant["summonerName"],
                                     stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase,
                                     region: region, summoner_id: participant["summonerId"])
      end
    end
    summoners
  end

  def check_match_history(region, summoner, others, retrys = 0)
    matches = get_match_history(region, summoner)
    # return unless @errors.empty? && matches["endIndex"] != 0
    return if matches.code != 200 || matches["endIndex"] == 0
    old_matches = matches
    matches = matches["matches"]
    lookup_matches(region, matches, summoner, others)
  end

  def get_match_history(region, summoner, retrys = 0)
    match_history_path1 = "/api/lol/"
    match_history_path2 = "/v2.2/matchlist/by-summoner/"
    key = get_key(region)
    match_history_uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                                         path: match_history_path1 + region + match_history_path2 + summoner.summoner_id,
                                         query: {
                                             api_key: key,
                                             beginIndex: 0,
                                             endIndex: NUMBER_OF_HISTORY_GAMES,
                                             rankedQueues: RANKED_QUEUES.join(",")
                                         }.to_query)
    json = HTTParty.get(match_history_uri)
    if json.code != 200
      if retrys < 7
        print "retrying match history #{{region: region, summoner: summoner.to_json, key: key}}\n"
        @failed_api_keys[key] += 1
        sleep(RETRY_SLEEP_TIME * retrys)
        return get_match_history(region, summoner, retrys + 1)
      else
        print "get match history failed: #{{region: region, summoner: summoner.to_json, key: key, json: json}}\n"
        @failed_api_keys[key] += 1
        @errors << "error getting match history for summoner '#{summoner.username}'"
        return json
      end
    end
    json
  end

  def lookup_matches(region, matches_json, summoner, others)
    match_ids = matches_json.map { |m| m["matchId"] }
    # print "looking up matches: #{match_ids} ##{match_ids.length}\n"

    cached_matches = nil
    ActiveRecord::Base.connection_pool.with_connection do
      cached_matches = Game.includes(:summoners).where(game_id: match_ids)
      cached_matches.inspect
    end
    cached_matches.each do |match|
      calculate_match(match, summoner, others)
    end
    match_ids -= cached_matches.map { |m| m.game_id.to_i }
    match_ids.each do |match_id|
      lookup_match(region, match_id, summoner, others)
    end
  end

  def lookup_match(region, id, summoner, other_summoner_ids)
    # print "looking up match: #{id}\n"
    match = nil
    ActiveRecord::Base.connection_pool.with_connection do
      match = Game.includes(:summoners).find_by(game_id: id) if Game.exists?(game_id: id)
      match.inspect
    end
    return calculate_match(match, summoner, other_summoner_ids) if match
    @threads << Thread.new do
      match = get_match(region, id)
      return unless match
      calculate_match(match, summoner, other_summoner_ids)
    end
  end

  def calculate_match(match, summoner, other_summoner_ids)
    @number_of_games[summoner] += 1
    summoners = nil
    ActiveRecord::Base.connection_pool.with_connection do
      summoners = match.summoners
      summoners.inspect
    end
    summoners.each do |match_summoner|
      @groups[summoner][match_summoner] += 1 if other_summoner_ids.include?(match_summoner.summoner_id)
    end
    unless summoners.count == 10 || summoners.count == 6
      @errors << {message: "bad match not right number of summoners",
                  summoners_count: summoners.count,
                  match: match}
    end
  end

  # returns Game object
  def get_match(region, id, retrys = 0)
    if retrys == 0
      # print "Getting match from riot\n"
    end
    match_path1 = "/api/lol/"
    match_path2 = "/v2.2/match/"
    key = get_key(region)
    match_uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                                 path: match_path1 + region + match_path2 + id.to_s,
                                 query: {api_key: key}.to_query)
    json = HTTParty.get(match_uri)
    if json.code != 200
      if retrys < 3
        print "retrying match #{{region: region, id: id, key: key}}\n"
        @failed_api_keys[key] += 1
        sleep(RETRY_SLEEP_TIME * retrys)
        return get_match(region, id, retrys + 1)
      else
        print "get match failed: #{{region: region, id: id, key: key}}\n"
        @failed_api_keys[key] += 1
        @errors << "There was an error retreiving match data {id: #{id}}"
        return false
      end
    end
    summoners = []
    ActiveRecord::Base.connection_pool.with_connection do
      json["participantIdentities"].each do |participant|
        participant = participant["player"]
        summoner = Summoner.where(summoner_id: participant["summonerId"])[0]
        if summoner
          summoner.update(username: participant["summonerName"],
                          stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase)
          summoners << summoner
        else
          summoners << Summoner.create(username: participant["summonerName"],
                                       stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase,
                                       region: region, summoner_id: participant["summonerId"])
        end
        # summoners << Summoner.find_or_create_by(username: participant["summonerName"],
        #                                         stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase,
        #                                         region: region, summoner_id: participant["summonerId"])
      end
      unless summoners.count == 10 || summoners.count == 6
        @errors << {message: "bad match not right number of summoners",
                    summoners_count: summoners.count,
                    match: json["participantIdentities"]}
      end
      begin
        Game.create(game_id: id, summoners: summoners)
      rescue ActiveRecord::RecordNotUnique => e
        Game.includes(:summoners).find_by(game_id: id)
      end
    end
  end
end
#TODO use action cable
# after action cable, check enemy team first
# TODO create get matches to take advantage of db
