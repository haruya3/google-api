require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google/apis/youtube_v3'

class Oauthorize
  
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob' #これは、コマンドラインで実行するのでWebで実行するときのRIDIRECT_PATHの代わり。
  APPLICATION_NAME = 'PlayListCreate'
  CLIENT_SECRETS_PATH = 'client_secret.json'
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials', "tokens.yaml")
  SCOPE = [ "https://www.googleapis.com/auth/youtube" ]


  def self.authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))
    #FileUtilsクラスのメソッドによって、二階層以上のディレクトリを一気につくっている。今回でいうと、Dir.home/.credentials
    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    #p client_id client.idとclient.secretとしてが格納されていた。
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    p credentials
    unless credentials  #初回だけ必要な処理。credentialを取得したら、2回目はCREDENTIALS_PATHに作られたtokens.yamlから参照する。
      #となると、トークンの有効期限を見て、更新の処理が必要になってくる。
      #credentailの中にrefresh_tokenもあるので、oauth/tokenへrefresh_tokenなどと一緒にリクエストすると更新できるはず。
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts 'Open the following URL in the browser and enter the ' +
          'resulting code after authorization'
      puts url
      code = gets.chomp
      #以下で、credentialの入手に成功すると、CREDENTIALS_PATHへの書き込みがされる。
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end
    
    #if "トークン削除" == gets.chomp, トークン削除して、もう一度認証からやり直すをやりたいが、できない。何も起きない。
      #user_refresh = Google::Auth::UserRefreshCredentials.new(client_id.id, client.secret, SCOPE)
      #p authorizer.revoke_authorization(user_id)
    #end
    return credentials
  end
end
