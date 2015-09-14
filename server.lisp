(setf sb-impl::*default-external-format* :UTF-8)
;;(declaim (optimize (debug 3)))
(ql:quickload '(cl-spider cl-json hunchentoot cl-mongo))

(defpackage such-cute
  (:use :cl :cl-spider :json :hunchentoot :cl-mongo))
(in-package :such-cute)

;;init db
(db.use "such-cute")
;;Cache time in seconds
(defvar cache-delay (* 60 2))

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
                                   ($>= "time" (- (get-universal-time) cache-delay)))))))
      (let* ((html (get-data uri)))
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

(defun local-uri-transfer(uri)
  (let* ((uri-obj (puri:parse-uri uri))
         (uri-host (string-downcase (puri:uri-host uri-obj))))
    (if (or (equal "127.0.0.1" uri-host) (equal "localhost" uri-host))
        "http://www.example.com"
        uri)))

(defun controller-get-block()
  (if (and (parameter "uri") (parameter "selector") (parameter "desires"))
      (handler-case
          (let* ((result (get-block-data
                          (local-uri-transfer (parameter "uri"))
                          :selector (parameter "selector")
                          :desires (and (parameter "desires") (decode-json-from-string (parameter "desires"))))))
            (cond
              ((parameter "callback")
               (progn
                 (setf (hunchentoot:content-type*) "application/javascript")
                 (concatenate 'string (parameter "callback") "(" (encode-json-to-string result) ");")))
              (t (progn
                   (setf (hunchentoot:content-type*) "application/json")
                   (encode-json-to-string result)))))
        (error
            (condition)
          (format nil "~A" condition)))
      "need more params: uri / selector / desires"))

(defun controller-get()
  (if (null (parameter "uri"))
      "Sorry sir, you must give me the uri."
      (handler-case
          (let* ((result (get-data
                          (local-uri-transfer (parameter "uri"))
                          :selector (parameter "selector")
                          :attrs (and (parameter "attrs") (decode-json-from-string (parameter "attrs")))
                          :html (get-cache (local-uri-transfer (parameter "uri"))))))
            (cond
              ((null (parameter "selector"))
               (progn
                 (setf (hunchentoot:content-type*) "text/plain")
                 (format nil "~A" result)))
              ((parameter "callback")
               (progn
                 (setf (hunchentoot:content-type*) "application/javascript")
                 (concatenate 'string (parameter "callback") "(" (encode-json-to-string result) ");")))
              (t (progn
                   (setf (hunchentoot:content-type*) "application/json")
                   (encode-json-to-string result)))))
        (error
            (condition)
          (format nil "~A" condition)))))

(setf *dispatch-table*
      (list
       (create-regex-dispatcher "^/get-block$" 'controller-get-block)
       (create-regex-dispatcher "^/get$" 'controller-get)))

(start-server)
