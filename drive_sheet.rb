require 'google_drive'
class DriveSheet
    attr_accessor :sheets, :session, :start_row_col
    def initialize(sheet_url)
        @session = GoogleDrive::Session.from_config("client_id_secret.json") #client_idとclient_secretを書いておくだけで、認証ページのurlも作って、トークン(refresh)を保存するファイルもロードしてくれる。
        #おまけに、そのファイルにscopeもclient_id_secret.jsonに付与してくれる。

        # スプレッドシート内で下タブに表示されているシートの1番目のものを取得
        # [1]や[2]と指定することで、順にワークシートを取得することが可能
        #@sheets = @session.spreadsheet_by_key(sheet_url).worksheets[0] #spreadsheet_by_key()には、シートのurlのd/以下をコピぺする。sheetに書き込みたかったらこっち。
        @sheets = @session.spreadsheet_by_key(sheet_url).worksheet_by_title("sheet1") #上ではworksheet型のオブジェクトになる。spreadsheet型にしたかったらこっち
        p @sheets
        @start_row_col = all_cells
    end
    
    def write_video_info(item: {}, index: 0, spread_sheet_vertical: 0, spread_sheet_line: 0, finish: 2)
        if index == 1
            #start_row_colに[1, 1]かfinishのセル番号が入っている。
            @sheets[@start_row_col, 1] = "検索結果 : #{Time.now.strftime("%Y/%m/%d %H:%M")}実行" 
            @sheets[(@start_row_col + 1), 1] = "--------------------------------------------------------------------"
        end 


        item_name_1 = %w(タイトル チャンネル 投稿日)
        video_info_1 = [item[:video_title], item[:video_channel_name], item[:video_published_at]]
        item_name_2 = %w(URL)
        video_info_2 = [item[:video_url]]
        item_name_3 = %w(再生回数 いいね 動画時間)
        video_info_3 = [item[:video_view_count], item[:video_like_count], item[:video_time]]
        item = [item_name_1, video_info_1, item_name_2, video_info_2, item_name_3, video_info_3]
        j = 0
        like_flag = false
        spread_sheet_line.times do |top_row|
            #新しくプログラムを実行した際の、書き込みスタート地点へ。まずtop_rowを初期化。
            top_row += (@start_row_col - 1) 
            #itemが次々にくるから、itemがindex番目のものなら、その分書き込む位置を調節
            #itemとitemの間には空白行がある。
            #itemの番号は(index)はフィルター通った順だから、最初に来たitemがindex1とは限らない。そこを修正しないと。
            top_row += (3 + (spread_sheet_line + 1) * (index - 1)) #最初のスタート地点 + (一つのitemの行数 + 空白行) * (何個目のitemか)
            @sheets.update_cells(top_row, 1, [item[j]])
            #色付け
            colorling(top_row, spread_sheet_vertical) if j.even?
            @sheets[(top_row + 1), 1] = "finish" if index == finish && j == (spread_sheet_line - 1)
            #jがitemごとの繰り返しの番号。
            j += 1
        end
        
        @sheets.save
        
    end

    def colorling(top_row, spread_sheet_vertical)
        @sheets.set_background_color(top_row, 1, 1, spread_sheet_vertical, GoogleDrive::Worksheet::Colors::ORANGE )
        @sheets.update_borders(
                (top_row + 1), 1, 1, spread_sheet_vertical,
                {bottom: Google::Apis::SheetsV4::Border.new(
                style: "DOUBLE", color: GoogleDrive::Worksheet::Colors::ORANGE)}
        )
    end

    #セルからfinishの位置をを取得する。
    def all_cells
        start_row_col = []
        (1..@sheets.num_rows).each do |row|
            (1..2).each do |col|
                #finishが見つかったら、その2行したから動画情報を書き込み始める。
               start_row_col.push((row + 2), 1)if @sheets[row, col] == "finish"
            end
        end
        #一度も書き込んでないよう
        return start_row_col = [1, 1] if start_row_col.empty?
        #最後から2番目の要素がスタート地点
        return start_row_col[(start_row_col.length - 2)]

    end

    def hello_world
        @sheets[1, 1] = "https://www.youtube.com/watch?v=Y4ySxP_IptE"
        array_first = [1, 2, 3, 4, 5]
        array_second = [6, 7, 8, 9, 10]
        #update_cells(top_row, left_col)
        sheets.update_cells(2, 1, [array_first])
        @sheets.save #saveをしないと、シートには反映されない。
    end

    def show
        p @sheets[1, 1] #すべて、文字列として返ってくる
       #p @sheets.input_value(1, 1)はオブジェクトそのままの形で返ってくる。
       #p @sheets.numeric_value(1, 1)は数値として取得できる。
    end

    def sheet_add(name)
        @sheets.add_worksheet(name)
    end

    def sheet_create(name)
        p @session.create_spreadsheet(name)
    end

    def drive_operation(sub_dir: "", name: )
        drive_dir = @session.collection_by_url("https://drive.google.com/drive/folders/1XbEuZGNJzYcuY5z09Ak3M-ttFSTLxoQQ")
        drive_sub_dir = drive_dir.create_subcollection(sub_dir)
        #p drive_dir
        #copy_sheet = @sheets.copy(name)#copyもないらしい。
        drive_sub_dir.add(sheet_create("trial")) #新しく作成したsheetを作ったサブディレクトリに保存できる。なぜか、@sheetは保存できない。
        #それは、@sheetsがgoogledrive::spreadsheetじゃなくてworksheetだから。
    end
end

#sheet_url = gets.chomp
#drive_sheet = DriveSheet.new(sheet_url)
#p drive_sheet
#p drive_sheet
#p drive_sheet.start_row_col
#drive_sheet.all_cells
#drive_sheet.hello_world
#p drive_sheet.sheets


#drive_sheet.write_video_info(item: item, index: 1, spread_sheet_vertical: 3, spread_sheet_line: 6, finish: 2)

#drive_sheet.show
#drive_sheet.sheet_add("practice") #add_worksheetというメソッドは、spreadsheetクラスのめそっどなのでレシーバにはspreadsheet型のオブジェクトをとる。
#drive_sheet.drive_operation(sub_dir: "trial-dir", name: "trial")

#drive_sheet.sheet_create("practice") #ちなみに、create_spreadsheetの戻り値は作成されたsheetのurl。しかも、spreadsheet_by_keyで使えるurlの部分。
##<GoogleDrive::Spreadsheet id="1xEst2ydiLR0ENsJABmK9qelJ0rwqA_DZgvn2xALQThs" title="practice">