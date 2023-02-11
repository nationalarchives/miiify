
class Response:
    def __init__(self, ctx):
        pass
    
    def to_json(self, data):
        items = []
        for item in data:
            items.append(item.json())
        return { 'items': items }