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

(defun controller-get-block()
  (if (and (parameter "uri") (parameter "selector") (parameter "desires"))
      (let* ((result (get-block-data
                      (parameter "uri")
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
      "need more params: uri / selector / desires"))

(defun controller-get()
  (let* ((result (get-data
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

(setf *dispatch-table*
      (list
       (create-regex-dispatcher "^/get-block$" 'controller-get-block)
       (create-regex-dispatcher "^/get$" 'controller-get)))

(start-server)
