require 'yt'

class Youtube_video < Oauthorize

    attr_accessor :youtube, :youtube_yt #attr_accessorをしないと、initializeの中だけの変数になってしまう。(変数のスコープ意識する)
    
    def initialize
        @youtube = Google::Apis::YoutubeV3::YouTubeService.new
        credentials = Oauthorize.authorize
        @youtube.authorization = credentials
        #playlistへの追加がgoogleのyoutube_v3ではできないので、非公式のYtというgemを使う。
        #ここで、Ytの認可の仕方はgoogleauthで取得したcredentialsを利用する。
        Yt.configure do |config|
          config.client_id = credentials.client_id
          config.client_secret = credentials.client_secret
        end
        @youtube_yt = Yt::Account.new(refresh_token: credentials.refresh_token) 
        p @youtube_yt
    end

    def video_serch(keyword: "人気" , video_duration: 'any', after: Time.now , before: Time.now)
        option = {
            q: keyword,
            type: 'video',
            video_duration: video_duration,
            max_results: 5,
            order: :rating, #評価順
            published_after: after.iso8601, #iso8601という形式にしている。
            published_before: before.iso8601
        }
        #youtube.key = 'AIzaSyAJ7Lr1brrN9cSJf4MnCNebKk_sQnlb4wQ'
        youtube_search_list = @youtube.list_searches(:snippet, option)
        result = file_operation(youtube_search_list) #ファイルへ、レスポンスを書き込む。
        
        #p results.class #string
        #p result.class #hash
        #p result["items"]
        #以下で、シンボルを使いたいなら21行目のJSON.parseでsymbolize_names: trueとする。そうすれば、シンボルのハッシュが生成される。
        video_ids = []

        result[:items].each do |item|
            video_ids << item[:id][:videoId]
        end
        result_hash = video_content(video_ids: video_ids)
        my_playlist_id(video_ids)
        return order(result_hash)
    end

    

    private

    #グッド数に応じて並べ替え。公開日や、動画時間を普通の形式に。Time型に。
    def video_content(video_ids: [])
        video_id_list = video_ids.join(',') #文字列にしてあげる。list_videosのオプションは、動画のidであり複数の場合は文字列でカンマ区切りで渡すことになっているから。
        options = {
            id:  video_id_list
        }
        youtube_video_content = @youtube.list_videos("statistics, snippet, contentDetails", options)
        result = file_operation(youtube_video_content)
        result_hash = {items: []}
    #なぜか、each_with_index do |index, item|とするとエラーになる。64行目が。|item, index|としてないから。。結局each_with_indexは使わなくてよい。
        result[:items].each do |item|
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

    def my_playlist_id(video_ids)
        options = {
            mine: true
        }
        youtube_channel_playlist = @youtube.list_playlists('snippet, contentDetails', options)
        #youtube_channel_playlist = @youtube.list_channels('snippet, contentDetails', options) なぜか、likesとuploadの再生リストしか取得できない。よくわからん。
        result = file_operation(youtube_channel_playlist)
        play_list_id = result[:items][0][:id] #ここで、追加するプレイリストを変えることができる。
        play_list_add_video(play_list_id: play_list_id, video_ids: video_ids)
    end

    def play_list_add_video(play_list_id: "", video_ids: "")
        youtube_play_list =  Yt::Playlist.new id: play_list_id, auth: @youtube_yt
        video_ids.each do |video_id|
            youtube_play_list.add_video video_id #ここで、一個ずつしか追加できないのがやばい。クウォータ制限すぐ行きそう。
        end
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

end
