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

(defun cache-uri(uri params html)
  (db.update
   "cache"
   (kv ($ "uri" uri) ($ "params" params))
   (kv ($set "time" (get-universal-time)) ($set "html" html))
   :upsert t :multi t))

(defun get-cache(uri params)
  (or (get-element "html"
                   (car (docs
                         (db.find "cache"
                                  (kv
                                   (kv "uri" uri)
                                   (kv "params" (write-to-string params))
                                   ($>= "time" (- (get-universal-time) cache-delay)))))))
      (let* ((html (html-select uri :params params)))
        (progn (cache-uri uri (write-to-string params) html) html))))
;
; Start Hunchentoot
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

(defun assemble-params(params)
  (and params
       (let* ((result))
         (dolist (x (decode-json-from-string params))
           (let* ((key (car (cl-ppcre:split " as " x)))
                  (val (cadr (cl-ppcre:split " as " x))))
             (push (cons key val) result)))
         result)))

(defun filt-uri(uri)
  (let* ((uri-host
          (string-downcase
           (cl-ppcre:regex-replace-all "http(s)?://|/" (cl-ppcre:scan-to-strings "^http(s)?://[a-zA-Z0-9-\\.]+[/]*" uri) ""))))
    (if (or (equal "127.0.0.1" uri-host) (equal "localhost" uri-host))
        "http://www.example.com"
        uri)))

(defun controller-get-block()
  (if (and (parameter "uri") (parameter "selector") (parameter "desires"))
      (handler-case
          (let* ((result (html-block-select
                          (filt-uri (parameter "uri"))
                          :params (assemble-params (parameter "params"))
                          :selector (parameter "selector")
                          :desires (and (parameter "desires") (decode-json-from-string (parameter "desires")))
                          :html (get-cache (filt-uri (parameter "uri")) (assemble-params (parameter "params"))))))
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
          (let* ((result (html-select
                          (filt-uri (parameter "uri"))
                          :params (assemble-params (parameter "params"))
                          :selector (parameter "selector")
                          :attrs (and (parameter "attrs") (decode-json-from-string (parameter "attrs")))
                          :html (get-cache (filt-uri (parameter "uri")) (assemble-params (parameter "params"))))))
            (cond
              ((and (null (parameter "selector")) (null (parameter "attrs")))
               (progn
                 (setf (hunchentoot:content-type*) "application/octet-stream")
                 (format nil "~A" result)))
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
