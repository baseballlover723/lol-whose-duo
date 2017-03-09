module MainHelper
  def summoner_name(summoner, summoner_champions)
    "<strong>#{summoner.username}</strong> (<strong>#{summoner_champions[summoner].name}</strong>)"
  end
end
