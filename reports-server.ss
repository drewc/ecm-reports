(import ./reports/ui/dashboard :ecm/login/conf :std/getopt :std/sxml/tal/syntax)
(export main)

(def (main . args)
  (call-with-getopt ecm-login-main args
    program: "login"
    help: "A simple httpd login server"
    (option 'address "-a" "--address"
      help: "server address"
      default: "0.0.0.0:8078")))

(def (ecm-login-main opt)
  (run (hash-ref opt 'address)))

(def reports-server #f)
(def (run address)
  (displayln "P" (std/sxml/tal/syntax#current-tal-output-port))
  (def errlog (##open-file [path: "/tmp/reports-server-error-log" create: 'maybe]))
  (update-conf)
  (set! reports-server (start-reports-http-server! address))
  (current-error-port errlog)
  (thread-join! reports-server))
