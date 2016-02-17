#!/usr/bin/python2.7
import sys, json
from goose import Goose

url = sys.argv[1]
g = Goose()
article = g.extract(url=url)

print json.dumps(dict(title=article.title,
                      meta=article.meta_description,
                      text=article.cleaned_text))
