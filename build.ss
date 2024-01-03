#!/usr/bin/env gxi
;; -*- Gerbil -*-

(import :std/build-script)

(defbuild-script
  '("httpd/handler"
    "reports/ui/utils" 
    (gxc: "reports/ui/dashboard" (extra-inputs: ("reports/ui/html/dashboard.html")))
    (exe: "reports-server")))
