require 'google/apis/youtube_v3'
require './youtube_oauth'
require './youtube_video'
require './drive_sheet'
require 'time'
require 'date'
require 'json'
require 'duration'

#Railsで作るときは、これらのメソッドはクラスにいれて管理する。これよりは、保守性は上がる。。
#後は、youtube_oauth.rbを取り込めば完了となる。
def main
  keyword = 'edm'
  duration = 'short'
  #以下から選べます。
  #any –これはデフォルトのデフォルトです。
  #long –20分をアップロード表示する。
  #medium –4分表20分ありの動画のみをアニメーション。
  #short –4分された動画よりもます。
  after = Time.parse('2021-01-01 00:00:00 +0900')
  before = Time.now
  count = 5
  video_view_count = 10000
  spread_sheet_url = '1Uj7qyXFpaLjvUeCPbFqrRLtFe7H67KFDpBKQ8Gen8ss'
  spread_sheet_vertical = 3
  spread_sheet_line = 6


  youtube_video = Youtube_video.new
  drive_sheet = DriveSheet.new(spread_sheet_url)  
  #まずは、探す動画のidを取得します。video_searchの返値は検索結果の動画の情報を加工したものを再生回数で並べ替えたhashが返ってくる。
  result_ordered_hash, addition_video_ids = youtube_video.video_serch(keyword: keyword, video_duration: duration, after: after, before: before, search_count: count, video_view_count: video_view_count)
  #どこから、spreadsheet書き始めるかしる。
  j = 0
  result_ordered_hash[:items].each_with_index do |item, index|
    #ここで、spreadsheetに書き込んでいく。
    #ここで、filter_already_videoメソッドの代わりをする。result_ordered_hashはfilter_already_videoメソッドをとおしてないから。
    next unless addition_video_ids.include?(item[:video_id])
    j += 1
    drive_sheet.write_video_info(item: item, index: j, spread_sheet_vertical: spread_sheet_vertical, spread_sheet_line: spread_sheet_line, finish: addition_video_ids.length)
    puts "チャンネル名: #{item[:video_channel_name]}\nタイトル: #{item[:video_title]}\nURL: #{item[:video_url]}\n動画時間: #{item[:video_time]}\n公開日: #{item[:video_published_at]}\n"
    puts "詳細情報\n"      
    puts "再生数: #{item[:video_view_count]}回, グッド数: #{item[:video_like_count]}, バッド数: #{item[:video_dislike_count]}, コメント数: #{item[:video_comment_conunt]}\n"
  end
end

main
