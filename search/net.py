from requests_futures.sessions import FuturesSession
from flask import abort

class Net:
    def __init__(self, ctx):
        self.max_workers = ctx.max_workers
        self.logger = ctx.logger

    def get(self, uris):
        try:
            session = FuturesSession(max_workers=self.max_workers)
            futures = [
                session.get(uri)
                for uri in uris
            ]
            result = [ future.result() for future in futures ]
        except Exception as e:
            self.logger.error(f"failed to communicate with miiify: {repr(e)}")
            abort(500)
        else:
            return result