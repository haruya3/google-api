require 'google/apis/youtube_v3'
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
  #まずは、探す動画のidを取得します。video_searchの返値は検索結果の動画の情報を加工したものを再生回数で並べ替えたhashが返ってくる。
  result_ordered_hash = video_serch(keyword: keyword, after: after, before: before)
  result_ordered_hash[:items].each do |item|
    puts "#{item[:video_channel_name]}\n#{item[:video_title]}\n#{item[:video_url]}\n動画時間: #{item[:video_time]}\n公開日: #{item[:video_published_at]}\n"
    puts "詳細情報\n"      
    puts "再生数: #{item[:video_view_count]}回, グッド数: #{item[:video_like_count]}, バッド数: #{item[:video_dislike_count]}, コメント数: #{item[:video_comment_conunt]}\n"
  end

end

def video_serch(keyword: "人気" , after: Time.now , before: Time.now)
    option = {
        q: keyword,
        type: 'video',
        max_results: 5,
        order: :rating, #評価順
        published_after: after.iso8601, #iso8601という形式にしている。
        published_before: before.iso8601
    }

    youtube = Google::Apis::YoutubeV3::YouTubeService.new
    youtube.key = 'AIzaSyAJ7Lr1brrN9cSJf4MnCNebKk_sQnlb4wQ'
    youtube_search_list = youtube.list_searches(:snippet, option)
    result = file_operation(youtube_search_list) #ファイルへ、レスポンスを書き込む。
    
    #p results.class #string
    #p result.class #hash
    #p result["items"]
    #以下で、シンボルを使いたいなら21行目のJSON.parseでsymbolize_names: trueとする。そうすれば、シンボルのハッシュが生成される。
    video_ids = []

    result[:items].each do |item|
        video_ids << item[:id][:videoId]
    end
    result_hash = video_content(youtube: youtube, video_ids: video_ids)
    return order(result_hash)

end

#グッド数に応じて並べ替え。公開日や、動画時間を普通の形式に。Time型に。
def video_content(youtube: nil , video_ids: [])
    video_id_list = video_ids.join(',') #文字列にしてあげる。list_videosのオプションは、動画のidであり複数の場合は文字列でカンマ区切りで渡すことになっているから。
    options = {
        id:  video_id_list
    }
    youtube_video_content = youtube.list_videos("statistics, snippet, contentDetails", options)
    result = file_operation(youtube_video_content)
    result_hash = {items: []}
#なぜか、each_with_index do |index, item|とするとエラーになる。64行目が。|item, index|としてないから。。結局each_with_indexは使わなくてよい。
    result[:items].each_ do |item|
        video_time = item[:contentDetails][:duration]
        video_published_at = item[:snippet][:publishedAt]
        video_time = Duration.new(video_time) #iso8601の形式(PT1~)を時間や分、秒まで分解してくれる。以下のようにDurationインスタンスで分解したものにアクセスできる。
        video_id = item[:id]
        response_content = {
            video_id: item[:id],
            video_url: "https://www.youtube.com/watch?v=#{video_id}",
            video_title: item[:snippet][:title],
            video_channel_name: item[:snippet][:channelTitle],
            video_published_at: Time.parse(video_published_at).strftime("%Y年%m月%d日 %H時%M分%S秒"), #文字列ならiso8601からTime型になおせる。さらに、見やすいフォーマットに。
            #strftimeはレシーバがTime型ならオッケー。
            video_time: "#{video_time.hours}時間#{video_time.minutes}分#{video_time.seconds}秒",
            video_view_count: item[:statistics][:viewCount] || "なし",
            video_like_count: item[:statistics][:likeCount] || "なし",
            video_dislike_count: item[:statistics][:dislikeCount] || "なし",
            video_comment_conunt: item[:statistics][:commentCount] || "なし"
        }
        result_hash[:items] << response_content
    end
    return result_hash
end

def my_channel_id(youtube)
    options = {
        mine: true
    }
    youtube_channel_contents = youtube.list_channels('snippet, contentDetails', options)
    result = file_operation(youtube_channel_contents)
    favorite_playlist_id 
end

def order(result_hash)
    #再生回数の昇順で並び替え
    result_hash[:items].sort! do |a, b| #なぜか、hash = sortとすると0番目の要素しか取得できない。しかたないので、result_hashを直接変更することにする。
        b[:video_view_count].to_i <=> a[:video_view_count].to_i
    end
    return result_hash
end

#多分、親クラスとして共通処理にして、細かいところはオーバーライドでいけそう。そっちの方が、保守性高そう。
def file_operation(youtube_list)
    result = JSON.parse(youtube_list.to_json, symbolize_names: true) #json形式じゃないと、JSON.parseはエラーになる。
    #多分、dumpメソッドはハッシュを引数に取るから、一回JSON.parseでjsonをhashにしなきゃいけないのかな。
    #でも、dumpだとgenerateを元にしてるメソッドだからただの文字列になってしまう。pretty_generateみたいにきれいな(見やすい)json形式にならない。
    results = JSON.pretty_generate(youtube_list) #返値は文字列

    File.open("serch_result.json", "w") do |f|
        f.write(results)
        f.write("\n")
    end
    return result
end

main