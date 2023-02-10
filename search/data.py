import glob
import io
import os, os.path
from whoosh.index import create_in
from whoosh.searching import Searcher
from whoosh.fields import *
from whoosh.qparser import QueryParser

class Data:
    def __init__(self, ctx):
        self.repo = ctx.repo
        self.annotation_limit = ctx.annotation_limit
        self.idx = None

    def __create_schema__(self):
        schema = Schema(title=TEXT(stored=True), path=ID(stored=True), content=TEXT)
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

    def __write_data__(self, index):
        writer = index.writer()
        for file in glob.iglob(f"{self.repo}/*/collection/*/body/value", recursive=True):
            text = self.__read_file__(file)
            writer.add_document(title=file, path=file, content=text)
        writer.commit()

    def load(self):
        schema = self.__create_schema__()
        idx = self.__create_index__(schema)
        self.__write_data__(idx)

    def search(self, term):
        qp = QueryParser("content", schema=self.idx.schema)
        query = qp.parse(term)
        with self.idx.searcher() as s:
            results = s.search(query, limit=self.annotation_limit)
            for res in results:
                print(res)
        



