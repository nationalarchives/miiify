from data import Data

class Context:
    pass

ctx = Context()
ctx.repo = "/Users/john/git/annotations"

def run():
    data = Data(ctx)
    data.load()
    data.search(u"Henry")

if __name__ == "__main__":
    run()