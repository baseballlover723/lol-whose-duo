REQUEST_BASE = ".api.pvp.net"
NUMBER_OF_HISTORY_GAMES = ENV["NUMBER_OF_HISTORY_GAMES"].to_i
NUMBER_OF_DUPLICATE_KEYS = ENV["NUMBER_OF_DUPLICATE_KEYS"].to_i
REGION_TRANSLATOR = {br: "BR1", eune: "EUN1", euw: "EUW1", jp: "JP1", kr: "KR", lan: "LA1", las: "LA2",
                     na: "NA1", oce: "OC1", ru: "RU", tr: "TR1"}.with_indifferent_access
RANKED_QUEUES = ["RANKED_FLEX_SR", "RANKED_SOLO_5x5", "RANKED_TEAM_3x3", "RANKED_TEAM_5x5", "TEAM_BUILDER_DRAFT_RANKED_5x5", "TEAM_BUILDER_RANKED_SOLO"]
KEY_SLEEP_TIME = (1.5 * NUMBER_OF_DUPLICATE_KEYS).seconds
KEYS = {}.with_indifferent_access
REGION_TRANSLATOR.each_key do |region|
  region_queue = Queue.new
  NUMBER_OF_DUPLICATE_KEYS.times do
    ENV["RIOT_API_KEYS"].split(" ").each do |key|
      region_queue << key
    end
  end
  KEYS[region] = region_queue
end

class MainController < ApplicationController
  def index
  end

  def search
    redirect_to lookup_path(region: params.require(:region), username: params.require(:username))
  end

  def lookup
    @errors = []
    @region = params.require(:region)
    @username = params.require(:username)
    @id = get_summoner_id @region, @username
    return unless @errors.empty?

    current_game = get_current_game @region, @id
    return unless @errors.empty?

    @summoners = get_current_game_participants @region, current_game
    ids = @summoners.map { |s| s.summoner_id }
    @groups = {}
    # ids.each do |id|
    #   @groups[id] = Hash.new(0)
    # end
    @summoners.each do |summoner|
      @groups[summoner] = Hash.new(0)
    end
    @summoners.each do |summoner|
      check_match_history(@region, summoner, ids.reject { |p| summoner.summoner_id == p })
    end
    # else
    #   @participants = current_game
    # end
  end

  def get_key(region)
    key = KEYS[region].pop
    puts "popped #{key} off of the #{region} queue, #{KEYS[region].size} keys left"
    Thread.new do
      sleep KEY_SLEEP_TIME
      KEYS[region] << key
      puts "readded key: #{key} to the #{region} queue, now #{KEYS[region].size} in queue"
    end
    key
  end

  def get_summoner_id(region, username)
    id_path1 = "/api/lol/"
    id_path2 = "/v1.4/summoner/by-name/"

    db_username = Summoner.where(region: region, stripped_username: username.gsub(/\s+/, "").downcase)[0]
    return db_username if db_username
    puts "asking riot for region: #{region}, username: #{username}'s id"
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
      puts "new current game"
      summoners = get_current_game_participants region, json
      Game.create(game_id: json["gameId"], summoners: summoners)
    end
    json
  end

  def get_current_game_participants(region, game)
    summoners = []
    game["participants"].each do |participant|
      summoners << Summoner.find_or_create_by(username: participant["summonerName"],
                                              stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase,
                                              region: region, summoner_id: participant["summonerId"])
    end
    summoners
  end

  def check_match_history(region, summoner, others, retrys = 0)
    puts "#{summoner.summoner_id}: #{others}"
    matches = get_match_history(region, summoner)
    return unless @errors.empty?

    matches = matches["matches"]
    puts "looking up matches: #{matches.map { |m| m["matchId"] }}"
    matches.each do |match|
      lookup_match(region, match["matchId"], summoner, others)
    end
  end

  def get_match_history(region, summoner, retrys = 0)
    match_history_path1 = "/api/lol/"
    match_history_path2 = "/v2.2/matchlist/by-summoner/"
    match_history_uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                                         path: match_history_path1 + region + match_history_path2 + summoner.summoner_id,
                                         query: {
                                             api_key: get_key(region),
                                             beginIndex: 0,
                                             endIndex: NUMBER_OF_HISTORY_GAMES,
                                             rankedQueues: RANKED_QUEUES.join(",")
                                         }.to_query)
    json = HTTParty.get(match_history_uri)
    if json.code != 200
      if retrys < 5
        puts "retrying match history #{{region: region, summoner: summoner.to_json}}"
        return get_match_history(region, summoner, retrys + 1)
      else
        puts "get match history failed: #{{region: region, summoner: summoner.to_json}}"
        @errors << "error getting match history for summoner '#{summoner.username}'"
        return json
      end
    end
    json
  end

  def lookup_match(region, id, summoner, other_summoner_ids)
    puts "looking up match: #{id}"
    match = Game.exists?(game_id: id) ? Game.find_by_game_id(id) : get_match(region, id)
    return unless @errors.empty?
    match.summoners.each do |match_summoner|
       @groups[summoner][match_summoner] += 1 if other_summoner_ids.include?(match_summoner.summoner_id)
    end
  end

  # returns Game object
  def get_match(region, id, retrys = 0)
    if retrys == 0
      puts "Getting match from riot"
    end
    match_path1 = "/api/lol/"
    match_path2 = "/v2.2/match/"
    match_uri = URI::HTTPS.build(host: region + REQUEST_BASE,
                                 path: match_path1 + region + match_path2 + id.to_s,
                                 query: {api_key: get_key(region)}.to_query)
    json = HTTParty.get(match_uri)
    if json.code != 200
      if retrys < 5
        puts "retrying match #{{region: region, id: id}}"
        return get_match(region, id, retrys + 1)
      else
        puts "get match failed: #{{region: region, id: id}}"
        @errors << "There was an error retreiving match data"
        puts "error: #{json}"
        return json
      end
    end
    summoners = []
    json["participantIdentities"].each do |participant|
      participant = participant["player"]
      summoners << Summoner.find_or_create_by(username: participant["summonerName"],
                                              stripped_username: participant["summonerName"].gsub(/\s+/, "").downcase,
                                              region: region, summoner_id: participant["summonerId"])
    end
    Game.create(game_id: id, summoners: summoners)
  end
end
