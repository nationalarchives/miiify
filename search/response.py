class Response:
    def __init__(self, ctx):
        self.remote_server = ctx.remote_server
        self.annotation_limit = ctx.annotation_limit

    def __simple_template__(self, q, page, uri, items):
        dict = {
            "@context": "http://iiif.io/api/search/2/context.json",
            "id": f"{uri}?q={q}&page={page}",
            "type": "AnnotationPage",
            "items": items,
        }
        return dict

    def __part_of__(self, q, page, total, uri, total_pages):
        first = f"{uri}?q={q}&page=0"
        last = f"{uri}?q={q}&page={total_pages}"
        dict = {
            "partOf": {
                "id": f"{uri}?q={q}",
                "type": "AnnotationCollection",
                "total": total,
                "first": {"id": first, "type": "AnnotationPage"},
                "last": {"id": last, "type": "AnnotationPage"}
            }
        }
        return dict

    def __paged_template__(self, q, page, total, uri, items):
        start_index = page * self.annotation_limit
        total_pages = int(total / self.annotation_limit)
        dict = self.__simple_template__(q, page, uri, items)
        dict.update(self.__part_of__(q, page, total, uri, total_pages))
        if page > 0:
            dict["prev"] = f"{uri}?q={q}&page={page-1}"
        if page < total_pages:
            dict["next"] = f"{uri}?q={q}&page={page+1}"
        dict["start_index"] = start_index
        return dict

    def __response__(self, q, page, total, uri, items):
        if total > self.annotation_limit:  # if paged response
            return self.__paged_template__(q, page, total, uri, items)
        else:
            return self.__simple_template__(q, page, uri, items)

    def annotations(self, path, q, page, total, data):
        items = []
        for item in data:
            items.append(item.json())
        uri = f"{self.remote_server}{path}"
        return self.__response__(q, page, total, uri, items)