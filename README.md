# such-cute
**Translate Web Page to JSON (Web Interface for [cl-spider](https://github.com/VitoVan/cl-spider#installlation) )**

## Installation

* Install [cl-spider](https://github.com/VitoVan/cl-spider#installlation) first

* Install [MongoDb](https://www.mongodb.org/downloads) and start the service

* Download server.lisp then load it:

```bash
wget https://raw.githubusercontent.com/VitoVan/such-cute/master/server.lisp
mkdir log
sbcl --load server.lisp
```

* Ok, now have fun:

[http://localhost:5000/get?uri=https://news.ycombinator.com/](http://localhost:5000/get?uri=https://news.ycombinator.com/)

[http://localhost:5000/get?uri=https://news.ycombinator.com/&selector=a](http://localhost:5000/get?uri=https://news.ycombinator.com/&selector=a)

[http://localhost:5000/get?uri=https://news.ycombinator.com/&selector=a&attrs=["href","text"]](http://localhost:5000/get?uri=https://news.ycombinator.com/&selector=a&attrs=["href","text"])

[http://localhost:5000/get?uri=https://news.ycombinator.com/&selector=a&attrs=["href as uri","text as title"]](http://localhost:5000/get?uri=https://news.ycombinator.com/&selector=a&attrs=["href%20as%20uri","text%20as%20title"])

[http://localhost:5000/get-block?uri=https://news.ycombinator.com/&selector=tr.athing&desires=[{"selector":"span.rank","attrs":["text as rank"]},{"selector":"td.title>a","attrs":["href as uri","text as title"]},{"selector":"span.sitebit.comhead","attrs":["text as site"]}]](http://localhost:5000/get-block?uri=https://news.ycombinator.com/&selector=tr.athing&desires=[{"selector":"span.rank","attrs":["text%20as%20rank"]},{"selector":"td.title>a","attrs":["href%20as%20uri","text%20as%20title"]},{"selector":"span.sitebit.comhead","attrs":["text%20as%20site"]}])

Since it returns JSON sometime, you may like to open your Developer Panel of your browser.

![](https://raw.githubusercontent.com/VitoVan/such-cute/master/screenshots/json.png)

## More Docs

Check [https://vitovan.github.io/such-cute/](http://vitovan.github.io/such-cute/)

## Another thing

If you have checked the source code, you may aware that there is 2 minutes cache-delay (* 60 2) each request, you can change it to anything.


## License

GPL v2
