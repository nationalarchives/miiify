import glob
import io
import os, os.path
from whoosh.index import create_in
from whoosh.searching import Searcher
from whoosh.fields import *
from whoosh.qparser import QueryParser

class InvalidFilePath(Exception):
    "Raised when no matching file path"
    pass

class Data:
    def __init__(self, ctx):
        self.repo = ctx.repo
        self.annotation_limit = ctx.annotation_limit
        self.remote_server = ctx.remote_server
        self.idx = None

    def __create_schema__(self):
        schema = Schema(container=TEXT(stored=True), annotation=ID(stored=True), content=TEXT)
        return schema

    def __create_index__(self, schema):
        if not os.path.exists("index"):
            os.mkdir("index")
        idx = create_in("index", schema)
        self.idx = idx
        return idx

    def __read_file__(self, file):
        with io.open(file,'r',encoding='utf8') as data:
            text = data.read()
            return text

    def __get_container_annotation__(self, file):
        match file.split('/'):
            case [_, _, _, 'git', 'annotations', container, 'collection', annotation, 'body', 'value']:
                return (container, annotation)
            case [_, 'data', 'db', container, 'collection', annotation, 'body', 'value']:
                return (container, annotation)                
            case _:
                raise InvalidFilePath
        
    def __write_data__(self, index):
        writer = index.writer()
        for file in glob.iglob(f"{self.repo}/*/collection/*/body/value", recursive=True):
            content = self.__read_file__(file)
            container, annotation = self.__get_container_annotation__(file)
            writer.add_document(container=container, annotation=annotation, content=content)
        writer.commit()

    def load(self):
        schema = self.__create_schema__()
        idx = self.__create_index__(schema)
        self.__write_data__(idx)

    def search(self, term, page):
        if page < 0: return None
        qp = QueryParser("content", schema=self.idx.schema)
        query = qp.parse(term)
        with self.idx.searcher() as s:
            page_length = self.annotation_limit
            results = s.search_page(query, page+1, pagelen=page_length)
            results_length = len(results)
            print(results_length)
            if page > (results_length / page_length): return None
            uris = []
            for r in results:
                container = r.get('container')
                annotation = r.get('annotation')
                uri = f"{self.remote_server}/annotations/{container}/{annotation}"
                uris.append(uri)
            return (results_length, uris)
        



