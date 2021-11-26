require 'google/apis/youtube_v3'
require './youtube_oauth'
require './youtube_video'
require 'time'
require 'date'
require 'json'
require 'duration'

#Railsで作るときは、これらのメソッドはクラスにいれて管理する。これよりは、保守性は上がる。。
#後は、youtube_oauth.rbを取り込めば完了となる。
def main
  keyword = 'EDM'
  after = Time.parse('2021-11-01 21:01:27 +0900')
  before = Time.now
  youtube_video = Youtube_video.new
  #まずは、探す動画のidを取得します。video_searchの返値は検索結果の動画の情報を加工したものを再生回数で並べ替えたhashが返ってくる。
  result_ordered_hash = youtube_video.video_serch(keyword: keyword, after: after, before: before)
  result_ordered_hash[:items].each do |item|
    puts "#{item[:video_channel_name]}\n#{item[:video_title]}\n#{item[:video_url]}\n動画時間: #{item[:video_time]}\n公開日: #{item[:video_published_at]}\n"
    puts "詳細情報\n"      
    puts "再生数: #{item[:video_view_count]}回, グッド数: #{item[:video_like_count]}, バッド数: #{item[:video_dislike_count]}, コメント数: #{item[:video_comment_conunt]}\n"
  end

end


main
