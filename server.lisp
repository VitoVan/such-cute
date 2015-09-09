(setf sb-impl::*default-external-format* :UTF-8)
;;(declaim (optimize (debug 3)))
(ql:quickload '(cl-spider cl-json hunchentoot cl-mongo))

(defpackage such-cute
  (:use :cl :cl-spider :json :hunchentoot :cl-mongo))
(in-package :such-cute)

;;init db
(db.use "such-cute")

(defun cache-uri(uri html)
  (db.update
   "cache"
   ($ "uri" uri)
   (kv ($set "time" (get-universal-time)) ($set "html" html))
   :upsert t :multi t))

(defun get-cache(uri)
  (or (get-element "html"
                   (car (docs
                         (db.find "cache"
                                  (kv
                                   (kv "uri" uri)
                                   ($>= "time" (- (get-universal-time) (* 60 2))))))))
      (let* ((html (get-what-i-want uri)))
        (progn (cache-uri uri html) html))))

;; Start Hunchentoot
(setf *show-lisp-errors-p* t)
(setf *acceptor* (make-instance 'hunchentoot:easy-acceptor
                                :port 5000
                                :access-log-destination "log/access.log"
                                :message-log-destination "log/message.log"
                                :error-template-directory  "www/errors/"
                                :document-root "www/"))

(defun start-server ()
  (start *acceptor*)
  (format t "Server started at 5000"))

(defun controller-doge-wow()
  (setf (hunchentoot:content-type*) "application/json")
  (format nil "~A" *request*))

(defun controller-doge-new()
  (setf (hunchentoot:content-type*) "application/json")
  (format nil "~A" *request*))

(defun controller-doge-test()
  (let* ((result (get-what-i-want
                  (parameter "uri")
                  :selector (parameter "selector")
                  :attrs (and (parameter "attrs") (decode-json-from-string (parameter "attrs")))
                  :html (get-cache (parameter "uri")))))
    (cond
      ((null (parameter "selector"))
       (progn
         (setf (hunchentoot:content-type*) "text/plain")
         result))
      ((parameter "callback")
       (progn
         (setf (hunchentoot:content-type*) "application/javascript")
         (concatenate 'string (parameter "callback") "(" (encode-json-to-string result) ");")))
      (t (progn
           (setf (hunchentoot:content-type*) "application/json")
           (encode-json-to-string result))))))

;;http://cl-spider.vito/doge/test?uri=http://v2ex.com/
;;http://cl-spider.vito/doge/test?uri=http://v2ex.com/&selector=span.item_title
;;http://cl-spider.vito/doge/test?uri=http://v2ex.com/&selector=span.item_title>a&attrs=["href","text"]
;;http://cl-spider.vito/doge/test?uri=http://v2ex.com/&selector=span.item_title>a&attrs=["href","text"]&callback=console.log

(setf *dispatch-table*
      (list
       (create-regex-dispatcher "^/doge/wow$" 'controller-doge-wow)
       (create-regex-dispatcher "^/doge/new$" 'controller-doge-new)
       (create-regex-dispatcher "^/doge/test$" 'controller-doge-test)))

(start-server)
