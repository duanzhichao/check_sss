# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

secret_key_base = "ieb5fyNg43q38lT0AmxL2cdHsc+lSYcDlP8t1SERVH7zFiOxSXMWEKpve6TtBtxi"

config :check_school, CheckSchoolWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: secret_key_base
