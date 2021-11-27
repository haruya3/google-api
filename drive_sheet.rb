require 'google_drive'
class DriveSheet
    attr_accessor :sheets, :session
    def initialize(sheet_url)
        @session = GoogleDrive::Session.from_config("client_id_secret.json") #client_idとclient_secretを書いておくだけで、認証ページのurlも作って、トークン(refresh)を保存するファイルもロードしてくれる。
        #おまけに、そのファイルにscopeもclient_id_secret.jsonに付与してくれる。

        # スプレッドシート内で下タブに表示されているシートの1番目のものを取得
        # [1]や[2]と指定することで、順にワークシートを取得することが可能
        @sheets = @session.spreadsheet_by_key(sheet_url).worksheets[0] #spreadsheet_by_key()には、シートのurlのd/以下をコピぺする。
    end
    
    def hello_world
        @sheets[1, 1] = "Hello World"
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

sheet_url = gets.chomp
drive_sheet = DriveSheet.new(sheet_url)
drive_sheet.hello_world
p drive_sheet.sheets
#drive_sheet.show
#drive_sheet.sheet_add("practice")なぜか、使えない。
#drive_sheet.drive_operation(sub_dir: "trial-dir", name: "trial")

#drive_sheet.sheet_create("practice") #ちなみに、create_spreadsheetの戻り値は作成されたsheetのurl。しかも、spreadsheet_by_keyで使えるurlの部分。
##<GoogleDrive::Spreadsheet id="1xEst2ydiLR0ENsJABmK9qelJ0rwqA_DZgvn2xALQThs" title="practice">