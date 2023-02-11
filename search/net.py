from requests_futures.sessions import FuturesSession

class Net:
    def __init__(self, ctx):
        self.max_workers = ctx.max_workers

    def get(self, uris):
        session = FuturesSession(max_workers=self.max_workers)
        futures = [
            session.get(uri)
            for uri in uris
        ]
        return [ future.result() for future in futures ] 