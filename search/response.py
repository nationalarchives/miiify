
class Response:
    def __init__(self, ctx):
        self.remote_server = ctx.remote_server

    def __response__(self, id, items):  
        dict = {
            "@context": "http://iiif.io/api/search/2/context.json",
            "id": id,
            "type": "AnnotationPage",
            'items': items
        }
        return dict
    
    def annotations(self, path, data):
        items = []
        for item in data:
            items.append(item.json())
        id = f"{self.remote_server}{path}"
        return self.__response__(id, items)