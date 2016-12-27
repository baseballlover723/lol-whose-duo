class Game < ApplicationRecord
  belongs_to :s1, class_name: "Summoner", optional: true
  belongs_to :s2, class_name: "Summoner", optional: true
  belongs_to :s3, class_name: "Summoner", optional: true
  belongs_to :s4, class_name: "Summoner", optional: true
  belongs_to :s5, class_name: "Summoner", optional: true
  belongs_to :s6, class_name: "Summoner", optional: true
  belongs_to :s7, class_name: "Summoner", optional: true
  belongs_to :s8, class_name: "Summoner", optional: true
  belongs_to :s9, class_name: "Summoner", optional: true
  belongs_to :s10, class_name: "Summoner", optional: true

  def summoners
    return [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10].compact
  end

  def summoners_lazy
    return Summoner.find([s1_id, s2_id, s3_id, s4_id, s5_id, s6_id, s7_id, s8_id, s9_id, s10_id]).compact
  end

  def self.include_summoners
    includes(:s1, :s2, :s3, :s4, :s5, :s6, :s7, :s8, :s9, :s10)
  end

  def self.my_create(game_id:, summoners:)
    Game.create(game_id: game_id,
                s1: summoners[0],
                s2: summoners[1],
                s3: summoners[2],
                s4: summoners[3],
                s5: summoners[4],
                s6: summoners[5],
                s7: summoners[6],
                s8: summoners[7],
                s9: summoners[8],
                s10: summoners[9])
  end
end
