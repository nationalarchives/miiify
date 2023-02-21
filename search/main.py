from data import Data
from net import Net
from response import Response
from configparser import ConfigParser
from flask import Flask, request, make_response
from flask import abort
import logging

app = Flask(__name__)

log_format = "%(asctime)s::%(levelname)s::%(message)s"
logging.basicConfig(level='INFO', format=log_format)
log = logging.getLogger()

class Context:
    pass

ctx = Context()

config_ini = ConfigParser()
config_ini.read("config.ini")

ctx.version = config_ini.get("main", "VERSION")
ctx.annotation_limit = config_ini.getint("miiify_search", "ANNOTATION_LIMIT")
ctx.remote_server = config_ini.get("miiify_search", "REMOTE_SERVER")
ctx.repo = config_ini.get("miiify_search", "REPO")
ctx.index = config_ini.get("miiify_search", "INDEX")
ctx.max_workers = config_ini.getint("miiify_search", "MAX_WORKERS")
ctx.server_port = config_ini.getint("miiify_search", "SERVER_PORT")
ctx.debug = config_ini.getboolean("miiify_search", "DEBUG")
ctx.cors = config_ini.getboolean("miiify_search", "CORS")
ctx.logger = app.logger

@app.route('/search')
def search():
    q = request.args.get('q')
    if q == None: abort(404)
    page = request.args.get('page', 0, type=int)
    (total, uris) = data.search(q, page)
    uri_responses = net.get(uris)
    response = r.annotations(request.path, q, page, total, uri_responses)
    custom_response = make_response(response)
    if ctx.cors: custom_response.headers['Access-Control-Allow-Origin'] = '*'
    return custom_response


# load and index data in Whoosh
data = Data(ctx)
data.load()
# communication with miiify
net = Net(ctx)
# format the response
r = Response(ctx)

if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=ctx.debug, port=ctx.server_port)