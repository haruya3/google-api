require 'yt'
require 'duration'

class Youtube_video < Oauthorize

    #attr_accessorをしないと、initializeの中だけの変数になってしまう。(変数のスコープ意識する）
    #video_idsやresult_hashをインスタンス変数にした方がいいのかまよう。
    attr_accessor :youtube, :youtube_yt 
    
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
        
        File.open("serch_result.json", "w") do |f|
            f.write("") #検索結果のjsonを格納するファイルを初期化
        end

    end

    def video_serch(keyword: "人気" , video_duration: 'any', after: Time.now , before: Time.now, search_count: 5, video_view_count: 10000)
        next_page_alt_token = ""
        filtered_video_ids = []
        result_hash = {items: []}
        loop do
            next_page_token = next_page_alt_token
            option = {
                q: keyword,
                type: 'video',
                page_token: next_page_token,
                video_duration: video_duration,
                max_results: 50,
                order: :rating, #評価順
                published_after: after.iso8601, #iso8601という形式にしている。
                published_before: before.iso8601
            }
            youtube_search_list = @youtube.list_searches(:snippet, option)
            result = file_operation(youtube_list: youtube_search_list, file_write_flag: false) #ファイルへ、レスポンスを書き込む。
            
            #p results.class #string
            #p result.class #hash
            #p result["items"]
            #以下で、シンボルを使いたいなら21行目のJSON.parseでsymbolize_names: trueとする。そうすれば、シンボルのハッシュが生成される。
            video_ids = []
    
            result[:items].each do |item|
                video_ids << item[:id][:videoId]
            end
    
            break if filtered_video_ids.length >= search_count || result[:nextPageToken].nil?

            return_result_hash, return_filtered_video_ids = video_content(video_ids: video_ids, video_view_count: video_view_count) 
            #検索結果のフィルターされた動画の詳細情報とidを配列に結合する。
            result_hash[:items].concat(return_result_hash[:items]) 
            filtered_video_ids.concat(return_filtered_video_ids)
            #p result_hash[:items]
            #p filtered_video_ids #ちゃんと、配列の要素が結合されてるか確認
            next_page_alt_token = result[:nextPageToken]
        end
        file_operation(youtube_list: result_hash, file_write_flag: true)
        #filterされたvideo_ids、つまり再生回数の条件を満たした検索結果の動画idをプレイリストに追加する
        addition_video_ids = my_playlist_id(filtered_video_ids)
        #並び替えしたプレイリストに追加する動画の情報のhash(フィルターかけてない)と最終的にプレイリストに追加する動画のid配列
        return order(result_hash), addition_video_ids
    end

    

    private

    #検索結果の動画の詳細情報を取得、また再生回数のフィルターメソッドも呼び出す
    def video_content(video_ids: [], video_view_count: 10000)
        #文字列にしてあげる。list_videosのオプションは、動画のidであり複数の場合は文字列でカンマ区切りで渡すことになっているから。
        video_id_list = video_ids.join(',') 
        options = {
            id:  video_id_list
        }
        youtube_video_content = @youtube.list_videos("statistics, snippet, contentDetails", options)
        result = file_operation(youtube_list: youtube_video_content, file_write_flag: false)
        #取得した動画のidをフィルターにかける
        filtered_video_ids = filter_view_count_video(search_video_result: result, video_view_count: video_view_count)
        p filtered_video_ids
        #これが、最終的にプレイリストに追加する
        result_hash = {items: []}
        result[:items].each do |item|
            video_id = item[:id]
            video_time = item[:contentDetails][:duration]
            video_published_at = item[:snippet][:publishedAt]
            #iso8601の形式(PT1~)を時間や分、秒まで分解してくれる。以下のようにDurationインスタンスで分解したものにアクセスできる。
            video_time = Duration.new(video_time)
            #フィルターされた動画idと一致するならresult_hashに追加
            if filtered_video_ids.include?(video_id)
                response_content = {
                    video_id: video_id,
                    video_title: item[:snippet][:title],
                    video_channel_name: item[:snippet][:channelTitle],
                    video_published_at: Time.parse(video_published_at).strftime("%Y年%m月%d日 %H時%M分%S秒"), #文字列ならiso8601からTime型になおせる。さらに、見やすいフォーマットに。
                    video_url: "https://www.youtube.com/watch?v=#{video_id}",
                    #strftimeはレシーバがTime型ならオッケー。
                    video_view_count: item[:statistics][:viewCount] || "なし",
                    video_like_count: item[:statistics][:likeCount] || "なし",
                    video_time: "#{video_time.hours}時間#{video_time.minutes}分#{video_time.seconds}秒",
                    video_dislike_count: item[:statistics][:dislikeCount] || "なし",
                    video_comment_conunt: item[:statistics][:commentCount] || "なし"
                }
                result_hash[:items] << response_content
            end
            #p result_hash
        end
        return result_hash, filtered_video_ids
    end

    #自分のチャンネルのプレイリストのidを取得
    def my_playlist_id(filtered_video_ids)
        options = {
            mine: true
        }
        youtube_channel_playlist = @youtube.list_playlists('snippet, contentDetails', options)
        result = file_operation(youtube_list: youtube_channel_playlist, file_write_flag: false)
        #ここで、追加するプレイリストを変えることができる。
        play_list_id = result[:items][0][:id] 
        return play_list_add_video(play_list_id: play_list_id, filtered_video_ids: filtered_video_ids)
    end

    #プレイリストに動画を追加
    def play_list_add_video(play_list_id: "", filtered_video_ids:  [])
        video_already_ids = play_list_item_ids(play_list_id)
        #プレイリストに既にある動画のidを確認
        #p video_already_ids
        #以下が最終的にプレイリストに追加する動画のid配列。
        
        addition_video_ids = filter_already_video(filtered_video_ids: filtered_video_ids, video_already_ids: video_already_ids)
        
        #最終的にプレイリストに追加する動画の確認
        #p addition_video_ids　
        youtube_play_list =  Yt::Playlist.new id: play_list_id, auth: @youtube_yt
        #add_videosとadd_videoがありadd_videosは引数にvideo_id: []を取る。
        youtube_play_list.add_videos addition_video_ids 
        return addition_video_ids
    end

    #検索結果の動画を追加するプレイリストにある動画のidを取得
    def play_list_item_ids(play_list_id)
        next_page_alt_token = ""
        video_already_ids = []
        index = 0
        loop do
            next_page_token = next_page_alt_token
            options = {
                max_results: 30,
                playlist_id: play_list_id,
                page_token: next_page_token
            }
            play_list_items = @youtube.list_playlist_items('snippet', options)
            result = file_operation(youtube_list: play_list_items, file_write_flag: false)
            
            break if result[:nextPageToken].nil? && index != 0#nextPageTokenがなくなったら、loopを抜け出す。
            
            result[:items].each do |item|
                video_already_ids << item[:snippet][:resourceId][:videoId] #resourceIdにはkindとvideoIdが入ってる。
            end
            next_page_alt_token = result[:nextPageToken]
            index += 1

            #p "#{index}回目！" #ループが繰り返されて、何回目で抜け出すかが分かる。つまり、break if result[:nextPageToken].nil?が正常に動いているかテストできる。
        end
        return video_already_ids
    end

    #プレイリストに既にある動画のidフィルター(同じ動画はプレイリストに追加しないようにするため)
    def filter_already_video(filtered_video_ids: [], video_already_ids: [])
        #こうしないと、eachで要素順がずれるのでとりだされない要素が発生するため、video_idsのコピー(深い)を作る。
        filtered_video_ids_alt = Marshal.load(Marshal.dump(filtered_video_ids)) 
        filtered_video_ids_alt.each do |video_id| 
           filtered_video_ids.delete(video_id) if video_already_ids.include?(video_id)
           p filtered_video_ids
        end
        return filtered_video_ids
    end

    #再生回数フィルター(liveフィルターつき)
    def filter_view_count_video(search_video_result: [], video_view_count: 10000)
        filter_video_ids = []
        search_video_result[:items].each do |item|
            #liveは含めないようにvideo_timeでフィルター
            video_time_duration = item[:contentDetails][:duration]
            video_time = Duration.new(video_time_duration)
            video_time_result = "#{video_time.hours}時間#{video_time.minutes}分#{video_time.seconds}秒"
            filter_video_ids << item[:id] if item[:statistics][:viewCount].to_i > video_view_count && video_time_result != "0時間0分0秒" 
        end
        return filter_video_ids
    end

    #結果を並べ替え
    def order(result_hash)
        #再生回数の昇順で並び替え
        result_hash[:items].sort! do |a, b| #なぜか、hash = sortとすると0番目の要素しか取得できない。しかたないので、result_hashを直接変更することにする。
            b[:video_view_count].to_i <=> a[:video_view_count].to_i
        end
        return result_hash
    end

    #youtube apiのレスポンスをhash型に変換、ファイルへの書き込み。
    def file_operation(youtube_list: "", file_write_flag: true)
        #json形式じゃないと、JSON.parseはエラーになる。
        result = JSON.parse(youtube_list.to_json, symbolize_names: true) 
        #多分、dumpメソッドはハッシュを引数に取るから、一回JSON.parseでjsonをhashにしなきゃいけないのかな。
        #でも、dumpだとgenerateを元にしてるメソッドだからただのjson文字列になってしまう。pretty_generateみたいにきれいな(見やすい)json文字列にならない。このどちらも文字列が返り値
        results = JSON.pretty_generate(youtube_list) #返値は文字列

        if file_write_flag
            File.open("serch_result.json", "w") do |f|
                f.write(results)
                f.write("\n")
            end
        end
        return result
    end

end
