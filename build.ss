#!/usr/bin/env gxi
;; -*- Gerbil -*-

(import :std/build-script)

(defbuild-script
  '("httpd/handler"
    "reports/ui/utils" 
    "reports/ui/dashboard"
    (exe: "reports-server")))
