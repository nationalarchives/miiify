import glob
import io
import os, os.path
from whoosh.index import create_in
from whoosh.searching import Searcher
from whoosh.fields import *
from whoosh.qparser import QueryParser
from flask import abort

class InvalidFilePath(Exception):
    "Raised when no matching file path"
    pass

class Data:
    def __init__(self, ctx):
        self.logger = ctx.logger
        self.repo = ctx.repo
        self.index = ctx.index
        self.annotation_limit = ctx.annotation_limit
        self.remote_server = ctx.remote_server
        self.idx = None

    def create_schema(self):
        schema = Schema(container=TEXT(stored=True), annotation=ID(stored=True), content=TEXT)
        return schema

    def create_index(self, schema):
        if not os.path.exists(self.index):
            os.mkdir(self.index)
        idx = create_in(self.index, schema)
        self.idx = idx
        return idx

    def read_file(self, file):
        with io.open(file,'r',encoding='utf8') as data:
            text = data.read()
            return text

    def get_container_annotation(self, file):
        match file.split('/'):
            case [_, _, _, 'git', 'annotations', container, 'collection', annotation, 'body', 'value']:
                return (container, annotation)
            case [_, 'data', 'db', container, 'collection', annotation, 'body', 'value']:
                return (container, annotation)                
            case _:
                raise InvalidFilePath
        
    def write_data(self, index):
        writer = index.writer()
        for file in glob.iglob(f"{self.repo}/*/collection/*/body/value", recursive=True):
            content = self.read_file(file)
            container, annotation = self.get_container_annotation(file)
            writer.add_document(container=container, annotation=annotation, content=content)
        writer.commit()

    def load(self):
        try:
            self.logger.info('loading data')
            schema = self.create_schema()
            idx = self.create_index(schema)
            self.write_data(idx)
            self.logger.info('loaded data')
        except Exception as e:
            self.logger.error(f"failed to load data: {repr(e)}")
            abort(500)
        else:
            return None
        

    def search(self, term, page):
        try:
            if page < 0: return (0, [])
            qp = QueryParser("content", schema=self.idx.schema)
            query = qp.parse(term)
            with self.idx.searcher() as s:
                page_length = self.annotation_limit
                results = s.search_page(query, page+1, pagelen=page_length)
                results_length = len(results)
                if page > (results_length / page_length): return (0, [])
                uris = []
                for r in results:
                    container = r.get('container')
                    annotation = r.get('annotation')
                    uri = f"{self.remote_server}/annotations/{container}/{annotation}"
                    uris.append(uri)
                result = (results_length, uris)
        except Exception as e:
            self.logger.error(f"failed to search data: {repr(e)}")
            abort(500)
        else:
            return result
        



