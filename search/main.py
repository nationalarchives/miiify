from data import Data
from net import Net
from configparser import ConfigParser

class Context:
    pass

ctx = Context()

config_ini = ConfigParser()
config_ini.read("config.ini")

ctx.name = config_ini.get("main", "NAME")
ctx.version = config_ini.get("main", "VERSION")
ctx.annotation_limit = config_ini.getint("miiify_search", "ANNOTATION_LIMIT")
ctx.remote_server = config_ini.get("miiify_search", "REMOTE_SERVER")
ctx.repo = config_ini.get("miiify_search", "REPO")
ctx.max_workers = config_ini.getint("miiify_search", "MAX_WORKERS")

def run():
    data = Data(ctx)
    data.load()
    uris = data.search(u"Henry")
    net = Net(ctx)
    resp = net.get(uris)
    print(resp)

if __name__ == "__main__":
    run()