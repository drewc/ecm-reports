(import :ecm/user/database :std/db/dbi)

(export #t)


(def current-user-token (make-parameter #f))

(def token-user-cache (make-hash-table))
