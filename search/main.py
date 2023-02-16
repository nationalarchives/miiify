from data import Data
from net import Net
from response import Response
from configparser import ConfigParser
from flask import Flask, request
from flask import abort

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
ctx.server_port = config_ini.getint("miiify_search", "SERVER_PORT")
ctx.debug = config_ini.getboolean("miiify_search", "DEBUG")


# load and index data in Whoosh
data = Data(ctx)
data.load()
# communication with miiify
net = Net(ctx)
# format the response
resp = Response(ctx)

app = Flask(__name__)

@app.route('/annotations/search')
def search():
    q = request.args.get('q')
    if q == None: abort(404)
    page = request.args.get('page', 0, type=int)
    (total, uris) = data.search(q, page)
    if uris == None: abort(404)
    uri_responses = net.get(uris)
    return resp.annotations(request.path, q, page, total, uri_responses)    

if __name__ == '__main__':
    app.run(debug=ctx.debug, port=ctx.server_port)